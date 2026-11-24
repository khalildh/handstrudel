package com.handstrudel.social.model

/** iOS `FeedService.ReportReason`: the raw value is both the label and `reports.reason`. */
enum class ReportReason(val raw: String) {
    SEXUAL("Nudity or sexual content"),
    HATE("Hate or harassment"),
    VIOLENCE("Violence or self-harm"),
    SPAM("Spam or scam"),
    STOLEN("Not their content"),
    OTHER("Something else"),
}
