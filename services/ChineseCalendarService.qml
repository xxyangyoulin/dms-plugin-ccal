pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Services

Singleton {
    id: root

    readonly property string pluginId: "chineseCalendar"
    readonly property string ccalPath: "ccal"

    // Ccal availability status
    property bool ccalAvailable: false
    property bool ccalChecking: false
    signal ccalCheckCompleted

    // Lunar data cache
    property var lunarDataCache: ({})
    property string currentLunarDay: ""
    property string currentLunarInfo: ""
    property int dataVersion: 0

    // Holiday data
    property var holidayCache: ({})
    property var holidayData: ({})
    property int holidayDataVersion: 0
    property bool holidayLoading: false
    property var holidayCacheTimestamp: ({})
    readonly property int cacheExpireDays: 7

    // Chinese numbers for lunar day display
    readonly property var chineseNums: ["", "初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
                        "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
                        "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"]

    // Signals (use different names to avoid conflict with property changed signals)
    signal lunarDataUpdated
    signal holidayDataUpdated

    // Update dates every minute
    Timer {
        interval: 60000
        running: ccalAvailable
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            // console.info("[ChineseCalendarService] Timer triggered, loading current month data...")
            if (ccalAvailable) {
                loadCurrentMonthData()
                loadHolidayData()
            }
        }
    }

    // Initialize: check ccal availability and load cached holiday data
    Component.onCompleted: {
        checkCcalAvailability()
        loadCachedHolidayData()
    }

    // Check if ccal command is available
    function checkCcalAvailability() {
        ccalChecking = true
        Proc.runCommand("ccal-check", ["which", ccalPath], (stdout, exitCode) => {
            ccalAvailable = (exitCode === 0)
            ccalChecking = false
            ccalCheckCompleted()
            if (!ccalAvailable) {
                console.info("[ChineseCalendarService] ccal not found, plugin will show installation prompt")
            } else {
                console.info("[ChineseCalendarService] ccal found, loading data")
                loadCurrentMonthData()
            }
        }, 50)
    }

    // Recheck ccal availability (for refresh button)
    function recheckCcalAvailability() {
        checkCcalAvailability()
    }

    // Load holiday data for current year with caching
    function loadHolidayData() {
        const today = new Date()
        const year = today.getFullYear()
        loadHolidayDataForYear(year)
    }

    // Load holiday data for a specific year
    function loadHolidayDataForYear(year) {
        const yearKey = year.toString()

        // Check if we already have data in memory
        if (holidayCache[yearKey]) {
            if (isCacheValid(yearKey)) {
                return
            }
        }

        // Try to load from local cache first
        const cached = loadHolidayDataFromCache(yearKey)
        if (cached && cached.data && cached.data.days && cached.data.days.length > 0) {
            if (isCacheValid(yearKey, cached.timestamp)) {
                processHolidayDataCn(cached.data.days)
                holidayCache[yearKey] = cached.data.days
                holidayCacheTimestamp[yearKey] = cached.timestamp
                holidayDataVersion++
                return
            }
        }

        // Fetch from API
        holidayLoading = true
        const fetchYear = yearKey
        Proc.runCommand("holiday-" + fetchYear,
            ["curl", "-s", "https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/" + year + ".json"],
            (stdout, exitCode) => {
                if (exitCode === 0) {
                    parseHolidayResponse(fetchYear, stdout)
                } else {
                    holidayLoading = false
                    // console.info("Failed to fetch holiday data for year:", fetchYear)
                }
            }, 50, 15000)
    }

    // Check if cache is valid (within 7 days)
    function isCacheValid(yearKey, timestamp) {
        const ts = timestamp || holidayCacheTimestamp[yearKey]
        if (!ts) return false

        const cacheTime = new Date(ts)
        const now = new Date()
        const daysDiff = (now - cacheTime) / (1000 * 60 * 60 * 24)
        return daysDiff < cacheExpireDays
    }

    // Load all cached holiday data from storage
    function loadCachedHolidayData() {
        const years = PluginService.loadPluginData(pluginId, "holidayYears")
        if (!years || !Array.isArray(years)) return

        for (let i = 0; i < years.length; i++) {
            const yearKey = years[i]
            const cached = loadHolidayDataFromCache(yearKey)
            if (cached && cached.data && cached.data.days) {
                holidayCache[yearKey] = cached.data.days
                holidayCacheTimestamp[yearKey] = cached.timestamp
                processHolidayDataCn(cached.data.days)
            }
        }
        holidayDataVersion++
    }

    // Load holiday data from cache for a specific year
    function loadHolidayDataFromCache(yearKey) {
        const cacheKey = "holiday_" + yearKey
        const cached = PluginService.loadPluginData(pluginId, cacheKey)
        if (!cached) return null

        return {
            data: cached.data,
            timestamp: cached.timestamp
        }
    }

    // Save holiday data to cache
    function saveHolidayDataToCache(yearKey, data) {
        const now = new Date().toISOString()
        const cacheEntry = {
            data: data,
            timestamp: now
        }

        const cacheKey = "holiday_" + yearKey
        PluginService.savePluginData(pluginId, cacheKey, cacheEntry)

        // Update years list
        let years = PluginService.loadPluginData(pluginId, "holidayYears")
        if (!years || !Array.isArray(years)) {
            years = []
        }
        if (years.indexOf(yearKey) === -1) {
            years.push(yearKey)
            PluginService.savePluginData(pluginId, "holidayYears", years)
        }

        holidayCacheTimestamp[yearKey] = now
    }

    // Parse holiday API response (holiday-cn format)
    function parseHolidayResponse(yearKey, responseText) {
        holidayLoading = false
        try {
            const response = JSON.parse(responseText)
            if (response.days) {
                holidayCache[yearKey] = response.days
                processHolidayDataCn(response.days)
                saveHolidayDataToCache(yearKey, response)
                holidayDataVersion++
            }
        } catch (e) {
            // console.info("Error parsing holiday data:", e)
        }
    }

    // Process holiday data from holiday-cn format
    function processHolidayDataCn(days) {
        for (let i = 0; i < days.length; i++) {
            const d = days[i]
            holidayData[d.date] = {
                name: d.name || "",
                isHoliday: !!d.isOffDay,
                isWorkday: d.isOffDay === false,
                wage: d.isOffDay ? 3 : 1
            }
        }
        holidayDataUpdated()
    }

    // Get holiday info for a specific date (format: YYYY-MM-DD)
    function getHolidayInfo(dateString) {
        return holidayData[dateString] || null
    }

    // Get holiday name for a specific date
    function getHolidayName(dateString) {
        const info = holidayData[dateString]
        if (!info) return ""
        if (info.isHoliday) return info.name
        if (info.isWorkday && info.name) return info.name + "班"
        return ""
    }

    function loadCurrentMonthData() {
        const today = new Date()
        loadMonthData(today.getFullYear(), today.getMonth())
    }

    function loadMonthData(year, month) {
        if (!ccalAvailable) return

        const monthKey = year + "-" + (month + 1).toString().padStart(2, "0")
        const args = ["-x", "-g", "-u", (month + 1).toString(), year.toString()]

        const fetchMonthKey = monthKey
        Proc.runCommand("ccal-" + fetchMonthKey,
            [ccalPath].concat(args),
            (stdout, exitCode) => {
                // console.info("[ChineseCalendarService] ccal callback for", fetchMonthKey, "exitCode:", exitCode)
                if (exitCode === 0) {
                    parseCcalOutput(fetchMonthKey, stdout)
                } else {
                    // console.error("[ChineseCalendarService] ccal command failed for:", fetchMonthKey, "exitCode:", exitCode)
                }
            }, 50)
    }

    function parseCcalOutput(monthKey, output) {
        // console.info("[ChineseCalendarService] parseCcalOutput for", monthKey, "output length:", output.length)
        const monthData = {
            days: {},
            monthInfo: {}
        }

        const monthMatch = output.match(/<ccal:month[^>]+cname="([^"]+)"/)
        if (monthMatch) {
            monthData.monthInfo.header = monthMatch[1].trim()
        }

        const dayRegex = /<ccal:day\s+value="(\d+)"[^>]*leap="([^"]*)"[^>]*cdate="(\d+)"[^>]*cmonthname="([^"]+)"[^>]*cdatename="([^"]+)"/g

        let match
        while ((match = dayRegex.exec(output)) !== null) {
            const gregDay = match[1]
            const isLeap = match[2] !== ""
            const lunarDayNum = parseInt(match[3])
            const lunarMonthName = match[4]
            const displayName = match[5]

            let lunarDayText = chineseNums[lunarDayNum]
            const fullLunarDate = (isLeap ? "闰" : "") + lunarMonthName + lunarDayText

            let solarTerm = ""
            if (displayName !== lunarDayText && displayName !== lunarMonthName && displayName.indexOf("月") === -1) {
                 solarTerm = displayName
            }

            monthData.days[gregDay] = {
                lunarDay: displayName,
                lunarDayRaw: lunarDayText,
                lunarMonthName: lunarMonthName,
                fullLunarDate: fullLunarDate,
                solarTerm: solarTerm
            }
        }

        lunarDataCache[monthKey] = monthData
        dataVersion++
        lunarDataUpdated()

        const today = new Date()
        const currentMonthKey = today.getFullYear() + "-" + (today.getMonth() + 1).toString().padStart(2, "0")
        // console.info("[ChineseCalendarService] parseCcalOutput checking:", monthKey, "vs", currentMonthKey)
        if (monthKey === currentMonthKey) {
            const dayKey = today.getDate().toString()
            const lunarDay = monthData.days[dayKey]?.lunarDay || ""
            // console.info("[ChineseCalendarService] parseCcalOutput MATCH! dayKey:", dayKey, "lunarDay:", lunarDay)
            currentLunarDay = lunarDay
            currentLunarInfo = monthData.monthInfo.header || ""
        } else {
            // console.info("[ChineseCalendarService] parseCcalOutput NO MATCH, not setting currentLunarDay")
        }
    }

    function getLunarDayForDate(day, month, year, cacheVersion) {
        const monthKey = year + "-" + (month + 1).toString().padStart(2, "0")
        const dayKey = day.toString()
        const cache = lunarDataCache[monthKey]
        if (!cache) return ""
        const dayData = cache.days?.[dayKey]
        if (!dayData) return ""
        return dayData.lunarDay || ""
    }

    function getFullLunarDateInfo(day, month, year) {
        const monthKey = year + "-" + (month + 1).toString().padStart(2, "0")
        const dayKey = day.toString()
        const cache = lunarDataCache[monthKey]
        if (!cache || !cache.days) return null
        return cache.days[dayKey] || null
    }

    // Calendar helper functions
    function weekStartJs() {
        return Qt.locale().firstDayOfWeek % 7
    }

    function startOfWeek(dateObj) {
        if (!dateObj) return new Date()
        const d = new Date(dateObj)
        const jsDow = d.getDay()
        const diff = (jsDow - weekStartJs() + 7) % 7
        d.setDate(d.getDate() - diff)
        return d
    }

    function getMonthData(year, month) {
        const monthKey = year + "-" + (month + 1).toString().padStart(2, "0")
        return lunarDataCache[monthKey] || null
    }

    function getMonthHeader(year, month) {
        const monthData = getMonthData(year, month)
        return monthData?.monthInfo?.header || ""
    }

    // Format date according to custom format string
    function formatDate(formatStr) {
        if (!formatStr) return ""
        const today = new Date()
        const day = today.getDate()
        const month = today.getMonth() + 1
        const year = today.getFullYear()
        const yearShort = year % 100

        const weekDays = ["日", "一", "二", "三", "四", "五", "六"]
        const weekDay = today.getDay()

        const monthNames = ["1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月"]
        const monthFullNames = ["一月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "十一月", "十二月"]

        // Zodiac animals mapped to earthly branch index
        const zodiacAnimals = ["鼠", "牛", "虎", "兔", "龙", "蛇", "马", "羊", "猴", "鸡", "狗", "猪"]

        // Get lunar info with fallback
        const monthKey = year + "-" + month.toString().padStart(2, "0")
        const dayKey = day.toString()
        const cache = lunarDataCache[monthKey]
        const dayData = cache?.days?.[dayKey]
        const lunarDay = dayData?.lunarDay || currentLunarDay || ""

        // Get lunar month name from the day's data (e.g., "十二月")
        const lunarMonthOnly = dayData?.lunarMonthName || ""

        // Get month header for year info (e.g., "丙午年正月大17日始")
        const lunarMonthName = cache?.monthInfo?.header || currentLunarInfo || ""

        // Parse lunar year info (e.g., "丙午年正月大17日始" -> "丙午")
        const lunarYearMatch = lunarMonthName.match(/([甲乙丙丁戊己庚辛壬癸][子丑寅卯辰巳午未申酉戌亥])年/)
        const lunarYear = lunarYearMatch ? lunarYearMatch[1] : ""

        // Extract zodiac from earthly branch (2nd char of lunar year)
        let zodiac = ""
        if (lunarYear.length >= 2) {
            const branch = lunarYear[1] // 子, 丑, 寅, etc.
            const branchIndex = "子丑寅卯辰巳午未申酉戌亥".indexOf(branch)
            if (branchIndex >= 0) {
                zodiac = zodiacAnimals[branchIndex]
            }
        }

        const lunarMonthInfo = currentLunarInfo || lunarMonthName

        // Use placeholders to prevent replaced values from being matched by later patterns
        const replacements = []
        function ph(value) {
            const idx = replacements.length
            replacements.push(value)
            return "\x00" + idx + "\x00"
        }

        let result = formatStr

        // Replace lunar format first (longer patterns first)
        result = result.replace(/LLLL/g, ph(lunarMonthInfo + lunarDay))
        result = result.replace(/LLL/g, ph(lunarMonthOnly + lunarDay))
        result = result.replace(/LL/g, ph(lunarDay))
        result = result.replace(/LA/g, ph(zodiac))
        result = result.replace(/LY/g, ph(lunarYear))

        // Replace gregorian formats (longer patterns first)
        result = result.replace(/dddd/g, ph("星期" + weekDays[weekDay]))
        result = result.replace(/ddd/g, ph(weekDays[weekDay]))
        result = result.replace(/MMMM/g, ph(monthFullNames[month - 1]))
        result = result.replace(/MMM/g, ph(monthNames[month - 1]))
        result = result.replace(/yyyy/g, ph(year.toString()))
        result = result.replace(/yy/g, ph(yearShort.toString().padStart(2, "0")))
        result = result.replace(/MM/g, ph(month.toString().padStart(2, "0")))
        result = result.replace(/M/g, ph(month.toString()))
        result = result.replace(/dd/g, ph(day.toString().padStart(2, "0")))
        result = result.replace(/d/g, ph(day.toString()))

        // Replace all placeholders with actual values
        result = result.replace(/\x00(\d+)\x00/g, (_, idx) => replacements[parseInt(idx)])

        return result
    }
}
