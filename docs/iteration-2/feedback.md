# Iteration 2 Feedback

This document tracks the feedback items for the second iteration.

## Items

### 1. Scrollbar placeholder area on the right needs optimization
* **Problem**: The note text field shows an unoptimized, large gray vertical block on the right side which acts as a scrollbar track/placeholder area.
* **Screenshot**: ![Scrollbar Placeholder Issue](https://pochi-file-uploads.getpochi.com/blob-1782925022604.?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Content-Sha256=UNSIGNED-PAYLOAD&X-Amz-Credential=6014c18302705bffb21520cf4f865c2b%2F20260701%2Fauto%2Fs3%2Faws4_request&X-Amz-Date=20260701T165702Z&X-Amz-Expires=561600&X-Amz-Signature=7c65741e26b7b894aeab29c271eaf0048c66114a439a29c82532ef0add3aadd8&X-Amz-SignedHeaders=host&x-amz-checksum-mode=ENABLED&x-id=GetObject)
* **Status**: ✅ Resolved — The note `TextEditor` always exposed a legacy (non-overlay) scroller, leaving a gray track block on the right. Hiding the editor's scroll content background and scroll indicators removes the placeholder while keeping scrolling functional.

### 2. Colored number of "In progress" tab
* **Problem**: The blue colored number "5" next to the "In progress" tab label is undesirable.
* **Screenshot**: ![In progress tab number color](https://pochi-file-uploads.getpochi.com/blob-1782929385166.?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Content-Sha256=UNSIGNED-PAYLOAD&X-Amz-Credential=6014c18302705bffb21520cf4f865c2b%2F20260701%2Fauto%2Fs3%2Faws4_request&X-Amz-Date=20260701T180945Z&X-Amz-Expires=561600&X-Amz-Signature=44970df7fb35abec06599c3f17080f4badc20e6475e7eadf719f25a7a6f8faad&X-Amz-SignedHeaders=host&x-amz-checksum-mode=ENABLED&x-id=GetObject)
* **Status**: ✅ Resolved — The selected tab's count was tinted with the accent color. The count now always uses the muted secondary style, so it no longer appears blue.

### 3. Inappropriate empty placeholder when searching returns no results
* **Problem**: When a search returns no results, the placeholder incorrectly displays "Nothing in progress" and "Press ⌥⇧2 to capture a region." instead of an appropriate empty state message for search results.
* **Screenshot**: ![Inappropriate search placeholder](https://pochi-file-uploads.getpochi.com/blob-1782929418986.?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Content-Sha256=UNSIGNED-PAYLOAD&X-Amz-Credential=6014c18302705bffb21520cf4f865c2b%2F20260701%2Fauto%2Fs3%2Faws4_request&X-Amz-Date=20260701T181019Z&X-Amz-Expires=561600&X-Amz-Signature=2fe634114550eecb698dcb6c015acba37ed53c82f22a354967fd2214aab85b9d&X-Amz-SignedHeaders=host&x-amz-checksum-mode=ENABLED&x-id=GetObject)
* **Status**: ✅ Resolved — The empty state only accounted for the status filter, not an active search. It now detects a non-empty query and shows a search-specific state (magnifying-glass icon, "No results", and "No matches in <tab>.") instead of the capture hint.
