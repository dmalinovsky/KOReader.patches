# KOReader.patches
The patches I've created for [KOReader](https://koreader.rocks/).

## [2-disable-sticky-keys.lua](2-disable-sticky-keys.lua)

This patch disables sticky keys — it's skipping duplicate keypresses of the same key within specified time interval. It's useful for the devices with hardware problems.

## [2-reload-book-on-hyphen-change.lua](2-reload-book-on-hyphen-change.lua)

This patch reloads current book after making user hyphenation change. It's useful for FB2 book format mostly, since ePubs handle user hyphenation changes gracefully. 

See https://github.com/koreader/koreader/issues/13462 for more details.

## [2-open-url.lua](2-open-url.lua)

This patch adds a new context menu item to open the selected text as an URL in the browser. Sometimes books don't have URLs formatted as hyperlinks, and this way one can open them regardless.

## [2-auto-save-font-size.lua](2-auto-save-font-size.lua)

This patch saves font size as default after its change. If you're wearing glasses during the day, but not in bed, this is useful to have the chosen font size applied to the next opened books.

## [deprecated-2-logical-page-count.lua](deprecated-2-logical-page-count.lua)

This patch builds logical page count. It was superseded by koreader/koreader#14405.
