package app.banh.admin.live

import org.junit.Assert.assertTrue

/** The backend log (fetched over HTTP) holds no customer data and no sign-in code outside the console mail blocks. */
object LogAudit {
    private val codeLine = Regex("""Mã đăng nhập của bạn là (\d{6})""")

    fun run(name: String, address: String) {
        val phone = LiveSupport.state("phone")
        run(listOf(name, "Spam Test", address.substringBefore(","), "Đường Giả", "Helper Limit Test", "Helper Street", phone, phone.drop(1)))
    }

    fun run(customerData: List<String>) {
        val lines = LiveSupport.logText().lines()
        // A console mail is "[mail] subject" plus body lines that carry no log prefix (the logger's lines start with an escape code).
        var inMail = false
        val outside = lines.filter { line ->
            if (line.startsWith("[mail]")) inMail = true else if (line.startsWith("\u001B[")) inMail = false
            !inMail
        }
        val codes = codeLine.findAll(lines.joinToString("\n")).map { it.groupValues[1] }.toSet()
        val sensitive = customerData + codes
        val leaks = outside.filter { line -> sensitive.any { it.isNotBlank() && line.contains(it) } }
        LiveSupport.note("36-log-audit", "log lines: ${lines.size}; mail lines: ${lines.size - outside.size}; codes seen: ${codes.size}; " +
            "checked ${sensitive.size} strings (names, phone, address pieces, codes) on ${outside.size} other lines; leaks: ${leaks.size}\n" + leaks.joinToString("\n"))
        assertTrue("sensitive text in ${leaks.size} log lines: ${leaks.take(3)}", leaks.isEmpty())
        assertTrue("the log had no mail lines at all, so the audit saw nothing", lines.size > outside.size && codes.isNotEmpty())
    }
}
