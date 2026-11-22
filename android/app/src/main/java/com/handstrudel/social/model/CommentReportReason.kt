package com.handstrudel.social.model

/** iOS `CommentReportReason`: raw value is sent to `comment_reports.reason`. */
enum class CommentReportReason(val raw: String, val title: String) {
    HARASSMENT("harassment", "Hate or harassment"),
    SEXUAL("sexual", "Sexual content"),
    VIOLENCE("violence", "Violence or self-harm"),
    SPAM("spam", "Spam or scam"),
    OTHER("other", "Something else"),
}
