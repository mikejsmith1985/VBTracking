# Changelog

All notable changes to this project are recorded here.

## [Unreleased]

### Changed

- **Every icon is lit like a neon sign, and they all come from one renderer.** The web app
  drew a volleyball while the native apps carried the player and the ball — the same product
  wearing two faces depending on how it was installed. All five now come from the same
  traced artwork and the same code: black ground, a bright tube along the shape's edge, a
  cyan wash behind it, and a frame around the tile. The frame follows what each icon gets
  cropped to — a rounded rectangle for a home screen, a circle for a watch face and for the
  `maskable` icon, which a browser may crop to a circle of 80% of its width.
- **The app icon is lit like a neon sign.** The same silhouette and ball, traced from the
  same artwork, but on black with a bright tube along the shape's edge, a cyan wash behind
  it, and a frame around the tile. The frame follows the shape each platform crops to — a
  rounded rectangle on the phone, a circle on the watch — because a rounded rectangle drawn
  for a watch face would have its corners sliced off.

- **The two apps agree about colour again.** The web app coloured the tally board by turn;
  the native one changed to colour by player and the web app was left behind, so the same
  season looked different in each. The web app now computes the identical colours from the
  identical numbers — one hue per player, their own turns as shades of it, and the jersey
  badge carrying the colour so the link to a person is stated rather than inferred.
- **The native stats table shows Turns and Court.** It has always computed both; only the
  web app printed them, so the same figures were visible in one app and not the other. Court
  appears only where a lineup was used, which is the rule the web app has always followed —
  without one it would be a column of dashes pretending to mean something.


### Fixed

- **The five-serve alert was invisible to VoiceOver.** A container in SwiftUI is not an
  accessibility element on its own, so the overlay had no identity: it could not be
  announced, and nothing behind it was hidden while it was up. It is now named, and marked
  modal, so the court behind it is ignored while the interrupt is on screen — which is the
  whole point of an interrupt.

- **A jersey number could trap you on the roster screen.** The number field brings up a
  number pad, a number pad has no return key, and nothing else on the screen dismissed one —
  so the keyboard sat over the tab bar and the page could not be left at all short of
  force-quitting the app. Every screen that takes typing now offers Done above the keyboard,
  and a drag down over the list puts it away too. Two interface tests cover it: one proves
  the way out exists, the other proves the tab bar is still reachable with a number
  half-typed.

- **The interface suite had never run, and could not have.** It failed three ways before a
  single test executed: no `CODE_SIGNING_ALLOWED=NO`, so the build reached for credentials the
  workflow deliberately holds none of; `-sdk iphonesimulator` forced onto a scheme that embeds
  a watch app; and `-uiTestFreshStore`, passed by every test since the day they were written
  and **read by nothing**, so ten tests ran against one accumulating pile of state and failed
  for reasons that had nothing to do with what they were testing. Each launch with that
  argument now gets an empty container of its own.
- **Starting a game no longer opens anything.** The naming sheet appearing at the whistle was
  the wrong call — that is the one moment the app must not put something in front of the
  operator. Naming waits on the header, where it can be done between rallies or afterwards.


### Fixed

- **An empty spot on the court could only be tapped on its outline.** It was drawn as a
  stroked border with nothing inside, so the box had no middle to hit — every tap that landed
  where anybody would aim did nothing, which read as needing to tap twice to "focus" the
  court. The whole box is now the target.
- **Tapping a player first started recording their serves.** Building a rotation player-first
  was therefore impossible: the first tap handed them the ball instead of picking them up.
  While an order is still being built, a tap on a player picks them up and the next tap says
  where they stand. Tapping them a second time still serves them, which is the way out for an
  operator who wants no rotation at all.
- **The court reopened after every rotation and had to be cancelled.** Two causes. Tapping
  whoever was already serving — the natural way to say "no, carry on" — cleared what was held
  but left the court sitting over the outcome controls. And a rotation with a gap in it opened
  no turn at all, so nobody was serving, so the app asked who serves next after every single
  rally. The serve now passes over an empty place to the next player standing, wrapping round;
  only an order nobody is standing in hands the ball to nobody.

### Added

- **Interface tests for all three.** Every one was invisible to the domain suite because every
  one was about what a tap does to a screen. They run on the build machine, which is the only
  place a screen exists.


### Added

- **A game can be named while it is being played.** The Track screen carries the opponent
  above the match, and tapping it opens who / where / when. It was only askable from the
  season screen before — three taps away and usually after the fact, which is how a game ends
  up in the record called "Unnamed opponent". Starting a game now also dates it today, because
  a game being tracked is being played today and a season full of "No date" is the cost of not
  saying so.
- **A past game shows its figures.** Opening a tracked game from the season gave its context,
  its results, its notes and a serve-by-serve record — but never what those serves came to.
  The same per-player table the Game tab draws now sits there too, whole-game or match by
  match. Read against the roster of *that* season, not today's: a player who left the squad
  still served the serves they served.


### Fixed

- **The wrist stopped updating until the watch app was force-quit.** Courts were ordered by a
  counter that lives in memory on the phone and starts again at zero every time that app
  launches — and iOS relaunches a backgrounded app constantly. A watch holding sequence 47
  from before the phone restarted then rejected every snapshot that followed as though it were
  older, and went on showing a court from twenty minutes ago. Ordering now goes by the moment
  the court was captured, which comes from one clock and survives as many relaunches as an
  evening produces; the counter still breaks a tie inside the same instant, which is the only
  thing it was ever good for.
- **A watch app that had just come up showed nothing until the phone next changed something.**
  The system holds the newest context but does not deliver it a second time, so the wrist now
  reads it on activation. Between rallies, waiting for the next change is a long time for a
  coach who has just raised their arm.


### Added

- **A player's name and number can be corrected.** Tap them on the Roster. Until now a name
  typed wrong on the first night could only be fixed by removing the player and adding them
  again — which starts a new person and leaves their serves attached to the old one. The
  editor changes the name on the player and the number on this season's membership, and says
  so on screen, because that split is the one thing about this app that cannot be
  retrofitted.


### Added

- **Privacy and support pages, at the two URLs the App Store will not accept a submission
  without.** Both live beside the web app on GitHub Pages, and both are written to be read
  rather than to satisfy a form. The privacy page says the only thing worth saying — the app
  collects nothing, has no server, and has no networking code at all — and then explains what
  that means for backups, for the watch link, and for a roster of children's names. The
  support page answers the questions somebody will actually have, including why a figure
  shows a dash instead of a zero.

  Neither is precached: they are read online, and they are not part of the offline app.


### Fixed

- **The minus bars and New game could not be seen.** They were `#1b2030` on a black screen —
  receding and disappearing are not the same thing. The whole palette had rules about ink on
  a fill and none about whether the fill itself could be found, which is exactly the check
  that was missing. They are now a mid-slate that stands 2.1:1 off the screen behind them,
  with a white minus at 9.9:1 on top of it, and a test that fails if a control's own
  background ever stops being visible.

### Changed

- **Height moved from the score tiles to the minus bars.** The tiles lose 9% (90 to 82 pt)
  and the minus gains 40% (20 to 28 drawn, 32 tapped), with the mark itself half again as
  large. The score is still the bigger target — that has not changed and should not — but a
  minus small enough to be obviously secondary turned out to be too small to hit while
  watching a court. The required ratio moves from 4:1 to 2.5:1 to say so, and a test now
  holds it from *both* sides: big enough to be the primary control, not so big that the
  correction is a decoration.


### Fixed

- **The scoreboard was unreadable in a lit room.** The tiles were the app's accent colour at
  22% over black, with the figure in the *same hue* on top — so the number, the tile and the
  screen behind were all nearly the same shade, and the whole page disappeared under any
  light. It now paints solid: a light blue tile for US, light lavender for THEM, near-black
  figures on both. The tile does the shining and the number does the reading.

  The palette is checked rather than eyeballed. Every figure clears 7:1 against the tile
  under it, the lesser controls clear 4.5:1, and the tiles are held to at least twice the
  brightness of the minus bars so a glance lands on the score first. The WCAG formula itself
  is pinned against its known anchors, because a wrong contrast function would let every one
  of those checks pass on colours nobody can read.

- **A tile was measured against point sizes rather than line heights.** A 44 pt font does not
  occupy 44 pt of a stack, so the check that the side's name fits beside the figure was
  measuring the wrong thing — it would pass a tile that clips and fail one that is fine.


### Fixed

- **The scoreboard's sizes were never the scoreboard's to set.** Every control used
  watchOS's bordered button style, which has a control height of its own and ignores a frame
  asked for inside it — so US and THEM rode on the edge of their pills instead of sitting
  inside them, and the minus buttons came out very nearly as tall as the scores whatever
  numbers were written down. The page now draws its own shapes, which is what makes
  `ScoreLayout` govern anything at all. A test forbids the bordered style on that screen.

### Changed

- **Bigger scores, much smaller minus buttons.** The score pill is 92 pt with a 46 pt figure
  and the side's name inside it; the minus is drawn at 14 pt — a seventh of the score — and
  tapped at 22, because a control small enough to read as secondary is smaller than a thumb
  and the difference is invisible and free. Adding a point happens every rally; taking one
  off happens when somebody made a mistake, and the control under the thumb should be the one
  that is right nearly every time. Tests hold the ratio, the tap size, that the pill has room
  for the name as well as the figure, and that the whole page still fits the shortest watch
  anybody owns.


### Added

- **An About page, with a tip jar on it.** One `About this app` row at the bottom of the
  Season screen — a screen read between matches, never during one. It says what the app is
  and the four things somebody would want to check before trusting it: free, no adverts,
  nothing locked, no account; the season stays on the phone; the watch talks to the phone
  directly; a copy of everything is one file away.

  The asking is one sentence with no "please" in it, no figure suggested, and no mention of
  what anything costs to run. It never appears on its own — no launch prompt, no sheet over a
  game, no reminder, no count of what anybody has given, no badge or "supporter" tier. A gift
  that buys something is a purchase, and a purchase in a free app belongs to Apple.

  The thank-you is a link handed to the browser, which is the one lawful way a free app can
  be paid outside Apple's system. Two tests hold that line: no shipped file may name StoreKit,
  PassKit or a card field, and the About screen must be a `Link` with nothing on it that
  collects anything. **The section does not render until a real https address is set** — a
  link that goes nowhere is worse than no link, so an unset one ships as an app with no tip
  jar rather than an app with a dead button. It now points at a real page, and a test notices
  if that ever stops being true — a blanked address would otherwise ship silently as an app
  with no way to say thanks.

  The page says "this app is free" rather than "everything I make is free". A pledge nobody
  can keep is worse than no pledge, and that one would be quoted back at the first thing that
  ever carries a price.


### Added

- **A scoreboard on the wrist for games nobody is tracking.** Two numbers, a tap each, on
  their own watch page, with a minus under each and **New game** across the bottom. No
  roster, no season, no log — a Saturday in the park does not go in the record and now
  cannot. Corrections are per side rather than a single undo: a scorekeeper who has given a
  point to the wrong team knows which team, and asking them to work out how many steps back
  that was, in a gym, is asking for the wrong correction. It knows the rule that makes a
  scoreboard worth more than counting on fingers: to the target and two clear, so 21–20 is
  still a game and 26–24 is not. It says who is on game point, keeps counting past the end
  because the people on court decide when to stop, and survives a sleeping wrist. Played to
  11, 15, 21 or 25.

### Fixed

- **A serve recorded on the wrist stayed marked "not sent" after it had landed.** The court
  travels on the fast channel and arrives at once; the confirmation travelled on its own by
  `transferUserInfo`, which is guaranteed but opportunistic and can take minutes. So the
  wrist sat saying "1 serve not sent" about a serve already safely on the phone and visible
  on its screen. What the phone holds now rides along with the court, read off the log so it
  survives the phone restarting and capped at fifty so a season does not travel to a wrist
  that needs the last few. The queued confirmation stays as the backstop for when no court
  could be sent at all.
- **A watch a version behind the phone would have shown no court at all.** Swift's generated
  decoder does not fall back to a property's default for a missing key — it throws, which the
  reader turns into "no court". Fields added after the first release are now read as optional,
  and a court from a phone that never knew about them acknowledges nothing rather than
  everything.


### Added

- **The rotate alert has three settings, chosen on the wrist that wears it.** A third watch
  page offers off, brief, or persistent. Off never mentions the rule. Brief buzzes once and
  clears itself after five seconds — long enough to look down mid-rally and read two numbers,
  gone before the next serve. Persistent buzzes on a beat until it is cleared, which is what
  it did before. Persistent is the default, because a coach who has never opened the page has
  not decided anything and the alert should keep behaving the way they asked for it. A value
  stored by some later version reads as the default too, never as off: silencing an alert
  nobody chose to silence is the one failure with nothing on screen to explain it.


### Added

- **The rotate alert reaches the wrist, and keeps buzzing until it is cleared.** A single tap
  on the wrist is exactly the thing a coach misses while watching a rally, and missing it
  means the wrong player serves a sixth — so it now pulses every 1.5 seconds, over both watch
  pages, until somebody taps "Got it". The phone works out when the rule fires (it holds the
  record; the watch cannot count a turn) and sends it with the court.

### Fixed

- **The watch's five-serve check never checked the five-serve rule.** It buzzed whenever the
  serving player had any points recorded — not the rule, and never was. The count it needed
  was never on the watch to begin with.
- **The offline guarantee was passing without reading anything.** The scan that proves no
  shipped file names a networking API split its input on `"
"`, but a Windows checkout is
  CRLF and Swift counts `"

"` as one character — so every file came back as a single line
  that began with its own header comment, was dropped as a comment, and left an empty string
  to search. It has read the real source since, and still finds nothing; both scans now
  assert they read something before reporting a file clean.

### Changed

- **Colour on the tally board means a player, not a turn.** "The green tallies are number 5"
  is something a coach can hold in their head across a match; "the green ones are the third
  turn" is not. Each player takes one hue, kept for as long as the board is up, and their own
  turns are shades of it so the turns stay separable without the colour stopping meaning a
  person. The jersey number carries the colour too, so the link is stated rather than
  inferred. Outcome is still carried by the shape of the mark, so the board reads without
  colour vision at all. The web app still colours by turn.
- **Nothing in either app can silence the wearer, and a test now says so.** A repeating haptic
  is one step from asking for an extended runtime session, and several session types suppress
  the wearer's own notifications for their duration — which would trade a rotation reminder
  for every message and camera alert of the evening. The alert uses a plain timer instead, and
  no shipped file may name a session, HealthKit, or the notification centre.


### Added

- **The rotation can be set on the court itself, in either direction.** An empty spot is now
  a button: tap it and then the player who stands there, or tap the player and then the
  spot. Both orders work, because before a match people think in both, and asking the
  operator to remember which way round it goes is asking them to look away from the court to
  find out. Each placement is its own event, so undo takes back one tap rather than the
  whole lineup. Before this, the only way to arrange six players was a list of names behind
  a button that appeared *after* an order already existed — which hid it from exactly the
  operator who had not made one yet. That button is now offered from the start.
- **Column headings on the serving tables.** The figures were four unlabelled columns; a
  reader had to work out for themselves whether `19/22` was serves-in over serves or
  something else.

### Changed

- **The points column says when it covers only part of a season.** Serves and serves-in span
  every game, because a paper sheet recorded them; points exist only where play was tracked
  serve by serve. On a season that mixes the two the heading is marked and a line underneath
  names both counts — "the 1 game of 5 tracked serve by serve" — so nobody compares two
  players down that column without knowing what is in it.
- **The app icon is the artwork itself, not a redrawing of it.** The silhouette the
  stakeholder chose is traced to a mask at icon size and committed alongside the original, so
  the icon can be recoloured or re-traced without hunting for the source file. The figure
  built from circles and capsules that stood in for it is gone.

### Changed

- **Offline is proved by reading the source, not by turning the radios off.** A test now
  walks every file that ships and fails if one so much as names a networking API — there are
  none, and no networking framework is imported anywhere. That replaces a manual
  aeroplane-mode run which was wrong twice over: it had been dropped as a release gate back
  in release 003, and aeroplane mode disables the Bluetooth the watch link runs on. It would
  have demonstrated that the app works offline by breaking the one thing this release exists
  for. The device check is now what a gym actually is: no Wi-Fi, no signal, Bluetooth on.

### Changed

- **The wrist court is designed for the smallest watch Apple still supports, not the
  operator's own.** The design target moves from a 42 mm screen to a 40 mm one (324 × 394
  pt), and the layout is now asserted against all seven sizes in the field — from a Series 6
  at 40 mm to an Ultra at 49 mm. The on-deck box clears its stated margin on every one of
  them. Supporting a device means the court has to be readable there, and the smallest
  screen is the only one that proves it.

### Added

- **The native app, written end to end.** Both apps now exist: the phone's tracking loop
  with its court picker, tally board, five-serve alert, substitutions and end-of-match
  choices; the correction screens for any past game; seasons, career, rosters, games entered
  from paper and imported in batches; saving and restoring the whole record; and on the
  wrist, the court itself with recording behind a deliberate swipe.
- **`VBPresentation`**, a third package target holding every decision a screen would
  otherwise make for itself — what a figure reads as, how big each box on the wrist is, what
  a tap on a player means, whether the wrist is telling the truth about how current it is,
  and how serves recorded on the wrist merge into the phone's log. There is no Mac here, so
  a SwiftUI view cannot be run: moving those decisions somewhere testable is what makes
  writing the screens blind an acceptable thing to do rather than a hopeful one.
- **The on-deck box is a measured requirement, not a visual one.** `CourtLayout` works out
  the six box sizes for the 42 mm watch, and a test asserts the on-deck box is at least one
  and a half times the smallest by area — with an interface test on the build machine that
  measures the real frames and asserts the same thing.
- **Reading a batch of games from paper**, ported with the three-route name matching the
  operator's own import needed: full name, then the jersey number the file declares, then
  first name — refusing ambiguity rather than guessing which child a serve belonged to.
- **Writing events back out**, held to the reader by a round-trip test over every kind of
  event, and through the backup format the web app reads.

### Fixed

- **There was no way to save a season unless a game existed.** Backup and restore lived on
  the Game screen, which shows nothing at all until a game is in progress or one has been
  picked — so an operator between games could not save their record, and an operator on a
  new phone could not restore it. Both now sit on the Season screen under **Your data**,
  where the record lives, and the restore is offered even before a first season exists —
  which is exactly the moment someone holding a backup and a new phone needs it.

### Added

- **The Swift port is now proved against the season that actually matters.** The operator's
  own record — nine players, four games copied from paper, one tracked serve by serve and
  then corrected, five games discarded along the way, and a team name with an apostrophe in
  it — is committed as a golden file and replayed through the native import and reducer.
  Every figure matches what the shipped web app derives from the same file: the roster and
  its numbers, each game's result and serves, the season record, the breakdown by opponent,
  every player's season figures, all three matches of the tracked game with their
  corrections applied, and time on court. Dashes stay dashes. A one-serve difference fails
  the build.

### Added

- **The log on disk, and the route a season takes across.** The event log is one
  append-only file of JSON lines: one write per event, flushed, so a crash loses at most the
  serve being written — and the next read discards that half-line and says so rather than
  guessing at it. Damage anywhere earlier stops the read instead of loading half a season
  while looking like a whole one.
- **A backup can be read and written in the shape the web app already uses.** A whole season
  survives a round trip through the native export and back with every figure intact, which
  is what lets both apps read the same season while the native one is still being built.
- **Importing the same backup twice is recognised, not doubled.** Each event that arrives
  without an identifier is given one derived from its place in the log and its own content,
  so the same file always produces the same identifiers, and a small ledger beside the log
  remembers what has already landed. A repeat import is refused with "nothing was changed".
- **`VBStore`**, a second package target holding the one type that touches a filesystem — so
  `VBCore` keeps its promise of having no I/O in it, and the rules about a half-written line
  stay testable on a machine with no device attached.

### Added

- **The rulebook now exists in Swift, and it counts the same.** `packages/VBCore` is a pure
  domain package — events, reducer, statistics, aggregation, migrations, and the court
  geometry — with no storage, no clock and no randomness. It builds and tests on the Windows
  workstation, which is the entire local development loop for the native release: only the
  screens need a Mac. **117 tests run in 0.02 seconds.**
- **The port is proved rather than trusted.** Both logs captured from shipped builds replay
  through the Swift reducer and produce figures identical to the JavaScript — roster,
  matches, turns, scores, per-player serves, serves in, points, turns taken, time on court,
  and which figures are dashes rather than zeroes. A one-serve difference fails the build.
  The rotation rule still does not reach backwards into a game recorded before it existed.
- **The build environment is a script, not a memory.** Swift on Windows links with MSVC, so
  `scripts/swift-env.ps1` puts the Visual Studio developer environment, the user PATH and
  `SDKROOT` into the shell; `scripts/vbcore-test.ps1` runs the suite. Without them the
  toolchain reports itself invalid for want of a linker, which is a confusing hour that
  nobody needs to spend twice.
- **The Xcode project is generated from a file a person can read.** `ios/project.yml`
  declares both apps, the App Group derived from the bundle id, and the test targets;
  `codemagic.yaml` builds them. Nothing hand-edits a `.pbxproj` on a machine that cannot
  open one.

### Added

- **A serve turn missed at the time can be added.** Every point in a match where a turn
  could have been missed now offers one: after each turn, and at the end of every match.
  Pick who served it and the turn appears in that exact place, holding one serve, open for
  its serves to be entered like any other correction. It takes no rotation position, so
  adding one to a match still being played cannot change who the app says serves next.

### Changed

- **The six on court are laid out as a court.** Net along the top, service position in the
  bottom-right corner, and the rotation running clockwise through the other five — the
  arrangement re-lays itself around whoever has the ball, so the order never has to be held
  in the head while watching the game. The flat grid of numbers it replaces was in roster
  order and said nothing about who served next.
- **The bench is shown as a bench**: below the court, under its own heading, outlined and
  dimmed. Who is on and who is off was previously a matter of reading small corner marks.
- **Every field on a game's record sits on its own row.** iOS gives a date input a minimum
  width of its own and overflows whatever column it is given — the date ran under the court
  field twice. A field that cannot overlap is worth more than a saved row.

### Fixed

- **The Game tab now shows the game picked on the Season screen.** It only ever showed the
  game being tracked, so the figures for a game already finished could not be reached at
  all. It names the game it is showing, offers one tap back to the live one, and opens that
  game's serve record directly. A game copied from paper shows its serves with dashes for
  the figures the paper never held.

### Added

- **Any game already played can be looked at serve by serve, and corrected.** Starting a
  new game used to hide every earlier one: only the game being tracked could be seen, so a
  figure entered wrongly stayed wrong. Every game on the Season screen now opens its own
  serve record — every turn, in the order it happened. Tapping a serve cycles it (point,
  in, out), a missed serve can be added, a turn can be moved to the player who actually
  served it, and a turn recorded by mistake can be deleted.
- **A full-screen alert when a server has taken their five.** The limit is the referee's to
  enforce and the easiest thing on the court to lose count of, so this is the one thing in
  the app that interrupts: it names who has finished, and who has the ball next when there
  is an order to say. Any tap clears it, and it is raised once — a sixth serve is still
  recorded, without a second nag.

### Changed

- **Substituting is now bench first: tap the player coming on, then tap who they replace.**
  It matches the order the swap happens on the court, and it drops both the double-tap —
  a thing to remember rather than a thing to do — and the delay that gesture forced on
  every tap of the picker. Tapping the incoming player a second time serves them without
  substituting, which is how an out-of-order server is still recorded.

### Fixed

- **Throwing a game away from the End match panel did nothing.** Arming the confirmation
  closed the panel and took the button with it, so the second tap that would have committed
  it had nowhere to land — it read as the app ignoring the request and returning to
  tracking. The panel now stays open for its own controls.

### Added

- **An import file holding games 1–4 only**, at `import/paper-games-1-4.json`. The 29 August
  game is already tracked in the app, so importing the complete five-game transcription
  would count it twice. The full five-game file stays as the record of what the sheets said.
  Both are covered by tests: every game must parse, every player must resolve against the
  roster, and every total must still reconcile with the figures written on the paper.
- **Any game can be discarded from its own record**, not only the one in progress. A game
  entered twice — the same match tracked live and also imported from paper — would
  otherwise count twice in the season with no way to undo it. Two taps, and the
  consequence is stated before the second.

### Added

- **The running version is shown** at the bottom of the Season screen. Nine releases went
  out in a day with no way for whoever was holding the phone to tell a broken fix from a
  stale copy. Now there is.
- **A new version lands on the first launch, not the second.** The page reloads itself once
  when a new service worker takes over. Waiting for a second launch looks exactly like a fix
  that did not work, and cost a round of "it is still broken" every release.
- **Games can be pasted instead of imported from a file.** On iOS, saving a JSON file from
  Safari lands it as `.json.txt`; opening it, selecting all and pasting is both shorter and
  harder to get wrong than the file round trip.

### Added

- **A game can be left part-way through.** Tapping End match now also offers ending the
  game where it stands — keeping every serve, however many matches were played — and
  throwing the game away. Neither meant leaving the tracking screen before; the only exits
  were ending two more matches that never happened, or hunting through another tab.
- **A server now rotates out after their five serves.** A run of five straight points left
  the same player serving forever: a turn only ended on a serve that lost the rally, so a
  server who kept scoring never handed on and the order stood still. The turn now ends at
  the league's limit and the serve passes to the next player.
- Nothing is discarded. All five serves stay with the player who took them, and a referee
  who miscounts and lets someone serve again is recorded by choosing that player once more
   — a second turn, every serve kept.
- **Games recorded before this rule existed are untouched.** The rule is written into the
  game when it starts rather than read from the code, because a rule read from the code
  applies backwards: it would have re-attributed serves in games already played. Both
  migration fixtures caught exactly that and are the reason it works this way.
- **A tracked game's match results can be set after the fact.** Marking each match as it
  ends is the fast path, but a match ended in a hurry — or before the app could ask — was
  stuck as "not recorded" for good. Every match of a tracked game now carries a Won / Lost /
  — control on its record, and the game's result still follows from them.
- **Notes are three named boxes**: what went well, what to work on, and anything else. Every
  paper sheet keeps the first two as separate lists, which says more about how the record is
  used than one free-text box could — and typing those headings by hand every game was work
  the app should be doing. Existing notes stay exactly where they are, in the third box.
- The transcribed import files now carry the two lists separately, so a batch lands in the
  right boxes rather than as one blob.

### Changed

- **Statistics rank by how often a serve landed in, not by points scored.** Ten points from
  a hundred serves used to sit above six from ten, which is the opposite of what those
  figures say about serving. Volume breaks ties, so among equal percentages the player who
  did it more often leads, and a player who has not served sorts last rather than counting
  as nought percent.

### Fixed

- **A success was reported in the colour of a failure.** "Added 4 games." appeared in the
  same red banner as every refusal, which makes an operator doubt something that worked.
  The banner now carries a tone: green for what succeeded, red for what did not. The paste
  box also stays open on failure, so a bad paste can be corrected rather than redone.
- **The focus ring bled into the field alongside it.** It was painted outside the control's
  box, so on a two-column row a focused field visually crossed into its neighbour and the
  two read as overlapping. The ring is now drawn inside, and the columns sit further apart.
- **A field could sit under the keyboard.** iOS does not shrink the viewport for the
  keyboard in a standalone app, so the notes box ended up behind it with the operator typing
  blind. The focused field now scrolls clear.
- The version badge module was briefly emptied by a bad in-place edit during this change.
  The test asserting it matches the service worker cache caught it at once — which is why
  that test checks agreement rather than mere existence.
- **The import no longer demands that two people typed a name the same way.** The roster is
  typed on a phone before a match; the file is transcribed from handwriting afterwards.
  Requiring "Layna" and "Layna Blankenship" to agree character for character is a rule the
  data cannot keep. Names are now matched by full name, then through the jersey number the
  file declares, then by first name.
- Ambiguity is still refused rather than guessed: if two players answer to one first name,
  the import stops and says so. Putting a serve against the wrong child is worse than asking.
- A failed match now **names the roster it was matched against**, so the mismatch can be
  seen instead of guessed at.
- **The file picker refused the file iOS had just saved.** It filtered on
  `application/json`, and iOS names the download `.json.txt` — so the file was greyed out
  and could not be chosen at all. The picker now sets no `accept` attribute at all, not even
  an empty one. The parser reads the
  contents and refuses anything that is not ours with a plain reason, so a guess at an
  extension must never be what stands between the operator and their own data.
- **Every submit button in the app was broken.** Save, Create, Add player and the game
  form did nothing when pressed. A click on anything without an action triggered a full
  redraw, which destroyed and rebuilt the form before the browser's own submit event could
  fire. Pressing Enter in a field still worked, which is why it went unnoticed. A stray tap
  now redraws only when it actually changed something, and never from inside a form.
- The whole test suite missed it because every form test dispatched a `submit` event
  directly, sailing straight past the click handler. Forms are now driven by **clicking the
  button a thumb would land on**; with the bug reintroduced, 10 of those 13 tests fail.
- **The Season screen no longer drifts off the right edge of a phone.** The season name,
  team and Save button sat on one row; a grid child defaults to `min-width: auto`, so the
  inputs refused to shrink below their own content and pushed Save off-screen entirely.
  The button now sits beneath the two fields, and every grid that holds text was given the
  `min-width: 0` it needed.
- **Stacked buttons no longer touch.** "Enter a game by hand" and "Import a batch of games"
  ran flush together and read as a single control. Eight points between them, and headings
  that follow a paragraph now have room to read as a new section.
- Checked at 393 px — an iPhone's logical width — across all seven screens: nothing extends
  past the right edge and nothing scrolls sideways.

### Changed

- Airplane-mode verification is no longer a release gate, at the stakeholder's decision: a
  native iOS app is expected before connectivity in a gymnasium matters. The app remains
  offline-capable — the service worker and the precache-completeness test are unchanged —
  but offline behaviour is no longer proven on the device before shipping.

### Added — Seasons, Career Players, and Game Context (`feature/seasons-and-career`)

**A player is now a person, and the number belongs to the season**

- A player is a career identity that outlives every roster. The jersey number moved onto
  the season's roster entry, where it belongs — next year the same child plays for a
  different team wearing a different number, and she is still the same child.
- Seasons have a name and a team. A player joins one either from the people already
  recorded or as someone new. Removing them from a season no longer deletes anything:
  the person stays, and every serve they recorded stays theirs.
- Switching seasons is refused while a game is under way, and says so.
- A season records the format it was played under, so a later release can vary matches per
  game or players on court without touching stored data.

**Everything already recorded became a season, with nothing lost**

- The first migration that does real work. It prepends one season and stamps a field onto
  the events that now need one. It renames nothing and splits nothing: the tidier migration
  shifts every index, which turns a bug into silent corruption of the only real season
  anyone has recorded.
- Proven against two committed fixtures — a release-001 log and a release-002 log, the
  latter carrying lineups, a rotation and a substitution — replaying to identical figures.
- No past match was retroactively declared lost. They are all undecided, because silence
  is not a defeat.

**Who was played, where, and how it went**

- Every game records a date, an opposing team, a location and a court, editable at any
  time including long after the game.
- Ending a match asks how it went, in the same tap. The game's result follows from its
  matches. An unmarked match counts toward neither side.
- The Season screen gives a win-loss record and a breakdown by opponent.
- Notes on every game — what went well, what to work on — because that is on every paper
  sheet, which is a stronger statement of what matters than anything anyone could say.

**The games from before the app existed**

- A game can be entered from paper: per player, serves in and serves out, at game level.
- A prepared batch imports in one action. Players are matched by name against the season's
  roster, and an unknown name aborts the whole import naming that player — a typo must not
  quietly invent a tenth person on a nine-player squad.
- All or nothing. A partial import would leave the operator unable to tell what landed.

**Statistics that admit what they do not know**

- Serves, serves in and serve percentage span every game. Points, turns and time on court
  cover the tracked games only, and the table says so in as many words.
- A figure that was never recorded shows as a dash. Never a zero — a zero would say the
  player served and won nothing, and would report worse figures than they earned.
- A career view: one player across every season, each with its own team and number, plus a
  combined total.
- Top scorer and top serve percentage are computed rather than tallied by hand at the
  bottom of a page.

### Added — Rotation, Substitutions, and Durable Data (`feature/rotation-and-subs`)

**Your data survives the upgrade**

- Games recorded on the previous release load unchanged, with nothing to confirm or
  re-enter. Verified against a log written by the shipped release-001 build and kept as a
  test fixture, so the check is against the format as shipped rather than as remembered.
- Stored data now carries a version and is carried forward on load through an ordered
  migration chain. The 1 to 2 step does nothing, because this release only adds event
  types — the point is that the mechanism is proven to run before a release needs it to do
  real work.
- Data written by a newer version is refused, explained, and left untouched rather than
  loaded or overwritten.
- If the carried-forward log cannot be written back, the app keeps running from what it
  read and leaves the original alone. A failed write is never worse than not trying.

**Backup and restore**

- **Save a backup file** on the Stats screen, in one action. On a phone it opens the
  native share sheet, so Save to Files is one tap; elsewhere it downloads.
- **Restore from a backup** replaces everything on the device, after a second deliberate
  tap that says so.
- A damaged, truncated, or unrelated file is refused with a plain explanation and changes
  nothing. A backup from a newer version is refused; one from an older version is carried
  forward like any stored data.

**The rotation serves for you**

- A match takes an ordered lineup of the six on court. It is per match, not per game — with
  nine on the roster three sit out, and who sits out changes every match. Matches 2 and 3
  open prefilled from the previous match, editable before the first serve.
- When a turn ends, the next player in the order becomes the server with no action taken.
  **A side-out is now one tap instead of two**, and the dock stays on the outcome controls
  instead of swapping to the picker.
- One undo still reverses one operator action: the serve and the advance it caused are
  reversed together. The advance is part of the serve transition rather than an event of
  its own, so this holds by construction.
- Any player can be chosen to override the order, and the rotation carries on from them.
- Serving from outside the lineup — usually a substitution not yet entered — is recorded
  and marked rather than refused, and it takes over the position that was due, so the order
  does not lag by one for the rest of the match.
- A lineup is optional. Below six players, or after skipping, the app behaves exactly as
  the previous release did.

**Substitutions**

- Double-tap a player on court, then tap whoever replaces them. They take that exact slot
  in the serving order, and the rotation follows.
- Serves already recorded stay with the player who took them, including when the
  substitution replaces the player mid-turn.
- Refused when the incoming player is already on court, is not on the roster, or is the
  same player. Undoable. A player who came off can come back on.
- Each match lists its substitutions: who came off, who came on, and at what point.

**Reading at arm's length**

- Player buttons now show one large jersey number instead of a number and a clipped name.
  Three characters and an ellipsis was never a name; the number is what you scan for.
  Full names stay on the tally board and in every statistics view.
- The current server is shown at display size, because the app chooses them now and a wrong
  one is the app's mistake to make obvious.
- New statistic: turns on court, counting turns a player was in the lineup for whether or
  not they served — which distinguishes sitting out from never reaching the service slot.

### Added — Volleyball Serve Tracker (`feature/volleyball-serve-tracker`)

The first release: an offline-first, installable web app for recording volleyball serve
outcomes courtside on a phone.

**Recording**

- Tap the serving player, then one of three outcomes: `OUT`, `IN — no point`, `IN — POINT`.
  A point keeps the same server; anything else is a side-out and closes the turn.
- Serve turns are inferred, never typed. A turn also closes when a different player is
  tapped, so a full side-out costs at most two taps.
- The side-out state disables the outcome controls outright rather than ignoring taps, so a
  serve cannot be recorded against the wrong player.
- Undo on every action. It works by dropping the last event and replaying the log, so
  statistics, turn boundaries, and turn colours all return to exactly their prior state, and
  a turn emptied by an undo disappears rather than lingering with zero serves.
- A repeat tap within 300 ms is treated as a stray double-tap and ignored — two serves
  cannot physically occur that close together.

**Serve turns and the five-serve limit**

- Each serve renders as its own tally mark, grouped by turn, with a different colour per
  turn from a six-colour palette. Consecutive turns can never share a colour.
- Outcomes are distinguished by mark shape, not colour, so the board is readable without
  colour vision.
- Turns running past five serves are recorded in full and flagged. Nothing is ever capped,
  truncated, or silently corrected — referees miscount, and the record should show it.

**Roster**

- Up to 20 players, each with a name and a jersey number. Jersey numbers are text, so a
  leading zero survives.
- Only entered players are displayed; there are no placeholder rows.
- Editable at any time, including mid-game. Editing a name or number keeps every recorded
  serve attached to that player.
- Removing a player requires a second, deliberate tap and states that their recorded serves
  will be discarded.

**Statistics**

- Serves, serves in, in percentage, points, and turns taken — at turn, match, and game
  scope. Game totals are the sum of the three matches by construction.
- A player who attempted no serves shows a dash, never `0%` or `NaN`.
- Everything is derived from the recorded serves on read; no total is stored separately, so
  none can drift.

**Offline and install**

- Installs to the Home Screen and launches standalone, portrait-locked, with safe-area
  insets respected.
- A hand-written service worker precaches an explicit list of every file in the tree and
  serves cache-first, so after install the app issues no network requests at all.
- All data lives on the device in `localStorage` behind a single adapter. The in-progress
  game, current match, active server, and every serve survive a force-quit.
- A storage failure raises a visible warning and keeps recording in memory rather than
  discarding serves silently.

**Mobile-first**

- The phone in portrait is the only supported form factor, not an adaptation of a wider
  layout. Outcome controls sit in the thumb zone; every control is at least 44 pt; double-tap
  zoom, pinch zoom, and pull-to-refresh are suppressed.

**Discarding a game**

- A game and every serve in it can be thrown away from the Stats screen, which is where
  test data gets noticed and is safely away from anything tapped during a rally.
- Two deliberate taps, with the consequence stated before the second. The roster survives.
- Discarding is an event like any other, so it replays deterministically and no statistic
  anywhere still counts the discarded game.

### Changed

- **The side-out announcement is gone.** A turn can only end two ways — a serve that wins
  no point, or a different player being chosen — so the state needs no banner. The dock is
  now a thin status row over exactly one action block: the outcome controls, or the player
  picker. Never both, and never a dimmed copy of either.
- Between servers, the picker stands where the outcome controls normally are. That swap is
  the signal, readable across a court without reading a word, and it makes recording a
  serve against the wrong player structurally impossible rather than merely discouraged —
  no control capable of recording one exists.
- **168 px returned to the tally board** between servers: the dock fell from 381 px to
  213 px on a 430 px viewport with a 9-player roster. The two states now differ by 12 px,
  so the outcome controls land in the same place every time they appear.
- Tapping **Change** while serving swaps the outcome controls for the picker and becomes
  **Cancel**, keeping the one-action-block rule intact.
- Outcome control captions now read "turn ends" rather than "side out".

### Fixed

- A player selected as server no longer appears on the tally board with an empty turn box
  and a `0 served` line before they have served. A just-opened turn holds no serves yet;
  drawing it read as a mistake, and the status row already names the current server.

### Known limitations

- The opponent's score is deliberately not tracked, so the app cannot determine the
  two-point margin on its own. It shows points earned on serve, flags when that figure
  reaches 21, and leaves ending the match to the operator reading the scoreboard.
- Only the current game is reviewable. Completed games are retained on the device, but there
  is no cross-game reporting, export, or sharing yet.

### Technical notes

- No runtime dependencies, no bundler, no backend. The repository root is the deployed
  artifact, which is what keeps the service worker's precache list auditable by reading it.
- State is an append-only event log reduced by a pure function. Imports point one direction
  only: `ui → state → domain`.
- 177 tests. Unit coverage of the whole domain and every render function; the storage
  adapter exercised against a real `Storage`; a journey test that drives the real UI
  against a real DOM; and a check that the service worker precaches every shipped file,
  because a missing entry there fails only on a phone in airplane mode.
- Specification, plan, and validation scenarios live in
  `specs/001-volleyball-serve-tracker/`.
