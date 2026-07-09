# RedditFilter

**Blocks promoted/sponsored posts (ads) in the Reddit feed.** Built as a Theos dylib, injected into the Reddit IPA via Sideloadly. Optional subreddit/keyword filtering is included as a bonus.

---

## What it does

- **Removes ads** — hides any post flagged `isAdPost`, `isPromoted`, or `isPromotedCommunityPostV2`
- Collapses the blank spacer Reddit leaves where a removed ad used to be
- **(Optional)** Hides posts from subreddits you block (e.g. `worldnews`)
- **(Optional)** Hides posts whose titles contain keywords you block (e.g. `giveaway`)
- In-app settings UI accessible from Reddit's settings screen
- Toggle the optional filters on/off without losing your lists (ad blocking is always on)

---

## Building

### Prerequisites

- macOS (for Theos)
- Xcode command line tools
- Theos installed at `~/theos`

### Local build

```bash
git clone https://github.com/yourusername/RedditFilter
cd RedditFilter
export THEOS=~/theos
make
```

The built dylib will be at `.theos/obj/arm64/RedditFilter.dylib`.

### GitHub Actions (automated)

Push to `main` → Actions tab → download the `RedditFilter-dylib` artifact.

---

## Injecting with Sideloadly

1. Download the Reddit IPA (decrypted, e.g. from decrypt.day)
2. Open Sideloadly
3. Drag the Reddit IPA into Sideloadly
4. Tick **"Inject dylib/framework"** → add `RedditFilter.dylib`
5. Enter your Apple ID
6. Click **Start**

---

## Using in-app

1. Open Reddit → **Profile → Settings**
2. Tap **Filters** (top-right button injected by the tweak)
3. Add subreddits and keywords via the `+` rows
4. Swipe left to delete entries
5. Toggle the switch to disable filtering temporarily

---

## How it works

Reddit's feed is a pipeline of `FeedElementTransformer` objects. Posts pass through `HidingFeedElementTransformer` (Reddit's own hide logic) and, for ads, `AdHidingFeedElementTransformer` / `AdFilteringFeedElementTransformer` in the `RedditAds_FeedComponents_Impl` module.

We hook `shouldHidePost:` on those transformers and return `YES` when the post is an ad. Ad detection reads these ObjC-bridged getters via KVC:

- `isAdPost`
- `isPromoted`
- `isPromotedCommunityPostV2`
- `isAdPostPDP`
- a non-nil nested `adPost` object

We also zero out `AdFeedBlankUnitSliceView` so removed ads don't leave an empty gap.

KVC is used deliberately: these are Swift properties exposed as ObjC selectors, and `-valueForKey:` resolves them at runtime while safely missing (caught) on object types that lack them — so the hook won't crash across minor Reddit updates.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| Posts not being hidden | Open Settings → Filters, confirm lists are populated and toggle is ON |
| App crashes on launch | Check you're using a compatible Reddit version (tested on 2026.27.0) |
| "Block r/..." not appearing on long-press | This is best-effort; use Settings → Filters instead |
| Sideloadly fails | Try a clean path for the IPA (e.g. `C:\Sideloadly\reddit.ipa`) |

---

## Compatibility

- Tested against Reddit 2026.27.0 (arm64)
- iOS 16–18
- Hooks `HidingFeedElementTransformer` — class name is mangled but stable across minor Reddit versions; if Reddit renames it in a major update the hook will silently no-op (won't crash)
