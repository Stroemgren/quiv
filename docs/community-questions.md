# Landing-page question research: real player questions for Game Buddy

Collected 2026-10-30. Purpose: real community questions (EU5, HOI4, Civ 7) usable as examples
and visuals on the landing page, plus evidence that wikis/guides lag behind patches.

## Method and caveats

- Sources actually read: Steam Community discussions (EU5 app 3450310, HOI4 app 394360,
  Civ 7 app 1295660), CivFanatics forums. Reddit blocks the crawler entirely; the Paradox
  forums sit behind a browser-check interstitial, so anything from forum.paradoxplaza.com is
  taken from search snippets and marked "(via search snippet)".
- Quotes are verbatim unless marked "(paraphrased)". Long posts are quoted in fragments.
- Dates: Steam omits the year for current-year (2026) posts; those are given as 2026.
- Capability tags: exact conditions, exact numbers, comparison, connections,
  defines/engine constants, version difference.
- Context: EU5 released 4 Nov 2025; patches 1.0.3 (10 Nov 2025), 1.0.5, 1.0.8, 1.0.10
  (Dec 2025), 1.1.x (early 2026), 1.2 Echinades (6 May 2026), 1.3 Pavia, 1.4 Rio Salado
  (28 Oct 2026). HOI4: Gotterdammerung (Nov 2024), Graveyard of Empires (Mar 2025),
  Peace for Our Time (Apr 2026, 1.18), Thunder at Our Gates (Jun 2026, 1.19). Civ 7:
  release Feb 2025; 1.1.1 (Mar 2025), 1.3.x + Tides of Power (Dec 2025), 1.4.0 "Test of
  Time" (May 2026, Legacy Paths replaced by Triumphs), 1.5.0 (Sep 2026).

---

## Europa Universalis V

### Theme: forming nations (exact conditions, hidden capital/culture/rank gates)

1. "Have 36 out of 33 locations required but still can't form country. Anyone know why?"
   - Thread: *Can't form Prussia*, Steam EU5, 20 Dec 2025.
     https://steamcommunity.com/app/3450310/discussions/0/684115079179816684/
   - Reply (20 Dec 2025): "There is a new bug in 1.0.10 that requires you to have your capital
     in the Prussia region to form Prussia". Another (27 Dec): "i also have to core the state
     as well before i can click the 'form prussia' event."
   - Capability: exact conditions + version difference.
   - Great answer: the full formation trigger for Prussia from the 1.0.10 files (location
     count, capital region, core requirement, rank) next to the 1.1 version, diffed.

2. "Wiki says 'If not Flag of Byzantium, then Byzantium does not exist' In game says that it
   should not exist?"
   - Thread: *Byzantium cant form Roman empire?*, Steam EU5, 17 Dec 2025.
     https://steamcommunity.com/app/3450310/discussions/0/684114729914881441/
   - Replies: "I added required number of provinces to form it and it still blocked since
     'Byzantium does not exist'"; "By popular demand the devs have agreed to change this
     trigger so that Byz can actually click the decision to form Rome"; "they apparently fixed
     the triggers but _not_ the country rank."
   - Capability: version difference (wiki vs game, patch vs patch) + exact conditions.
   - Great answer: the Roman Empire formable's trigger block per version, showing the
     Byzantium clause and the rank requirement that still blocks it.

3. "Hi, i'm playing with the two sicily, i have conquered most of the italian peninsula, but
   it didn't show italy as formable country, can u tell me why?"
   - Thread: *Forming italy not showing up*, Steam EU5, 24 Dec 2025.
     https://steamcommunity.com/app/3450310/discussions/0/684115079180051189/
   - Replies: "Is your primary culture in the Italian group? Is your capital in Italy? Did
     someone else already form Italy?"; "From the game files, these are the requirements to
     form italy:" ... "check your nation formation settings if you have 'historical',
     'plausible' or 'all' formables allowed."
   - Capability: exact conditions (players already resort to reading game files).
   - Great answer: the Italy formable document: required locations, culture group, capital,
     rank, and the game-rule (formable type) gate the player missed.

4. "I'm doing a persia run, started as ayyoubids and formed Kurdistan." ... owns more than the
   270 required locations but the form-Persia button still does not work (paraphrased).
   - Thread: *Can't form Persia, is it a bug or am I missing something ?*, Steam EU5, 9 Mar 2026.
     https://steamcommunity.com/app/3450310/discussions/0/798963828253680149/
   - Replies: "Where is your capital? Many nation formations require that your capital is in
     one of the required locations"; "It only requires owning 50% locations of persian region
     and be in iranian culture group."
   - Capability: exact conditions (hidden capital condition).
   - Great answer: the exact Persia trigger, including the capital clause two commenters
     disagree about.

5. "Why it is even there? As Castile I have a union with Naples." (forming Italy / Two
   Sicilies blocked by culture requirement even after forcing Castilian on Naples)
   - Thread: *Culture requirements for forming countries*, Steam EU5, 9 Sep 2026.
     https://steamcommunity.com/app/3450310/discussions/0/568171134404566302/
   - Reply: "There is option in Game rules called Allow Ahistorical - All countries can be formed".
   - Capability: exact conditions + connections (country -> culture -> culture group -> formables).
   - Great answer: which cultures satisfy each formable, and what "primary culture" checks.

6. "Is there an event, or are there conditions that must be met in order to create the
   Polish-Lithuanian Commonwealth?"
   - Thread: *Making Polish-Lithuanian Commonwealth?*, Steam EU5, 18 Nov 2025.
     https://steamcommunity.com/app/3450310/discussions/0/802331493180500991/
   - Reply: "To form PLC, you must own:" krakow, vilnius, warsaw.
   - Capability: exact conditions.
   - Great answer: the PLC formable plus the union/dynasty event chain that references it.

7. "As brandenburg I only have the option to form either the hre or germany, not prussia."
   - Thread: *Prussia*, Steam EU5, 5 Nov 2025.
     https://steamcommunity.com/app/3450310/discussions/0/667222425710233529/
   - Replies: "Are you a rank II country? Prussia is a rank II formable."; "In order to form
     Prussia as Brandenburg you need to fulfill a hidden mission" ... "to reclaim some of the
     lost lands of the empire from the Teutons."; "maybe you need to hold Konigsberg for the
     decision to show."
   - Capability: exact conditions (hidden).
   - Great answer: the visibility ("potential") vs "allow" conditions of the decision.

8. "How to become theocracy as monarchy?"
   - Thread: same title, Steam EU5, 3 Feb 2026.
     https://steamcommunity.com/app/3450310/discussions/0/724651198970601303/
   - Reply: "Country >> Form New Country >> Reform into a Theocracy" ... "There are conditions
     you need to fulfill first like high Spiritualist value and high Clergy Estate Power."
   - Capability: exact conditions (exact thresholds instead of "high").
   - Great answer: the numeric thresholds in the reform's trigger.

9. "It says i cant form an empire because of 'Papal Ban on Empires'." Is this hard coded for
   the entire globe ATM ... or can you circumvent this somehow without dismantling the HRE?
   - Thread: *How to form an empire?*, Steam EU5, 10 Nov 2025.
     https://steamcommunity.com/app/3450310/discussions/0/667222787666174041/
   - Replies: "You can just convert away from catolicism, then papal laws won't apply.";
     later (26 May 2026): "with sufficiently low Clergy power you can declare yourself an
     Empire as a Catholic nation".
   - Capability: connections (IO law -> effect on rank change -> what lifts it).
   - Great answer: the Catholic Church IO law document and every trigger that references it.

### Theme: government reforms, laws, societal values

10. "We have currently equal or greater than 95 Aristocracy vs Plutocracy. How do you manage to
    get to 95?"
    - Thread: *Reform into Republic as the Netherlands (Aristocracy vs Plutocracy)*, Steam EU5,
      9 Nov 2025. https://steamcommunity.com/app/3450310/discussions/0/667222787666017160/
    - Replies: "The quickest way to move further on the scale is taking event options that push
      you on that scale."; "in eu5 you do not have 0-100 Aristocracy AND 0-100 Plutocracy in
      game files."
    - Capability: exact numbers + connections (every event/privilege/law that moves the axis).
    - Great answer: the reform's requirement line, and the list of modifiers/events touching
      aristocracy_vs_plutocracy.

11. "I have been trying to form a republic for 300 years" (needs 95+, stuck at 87; the
    parliament reform giving +10 has not appeared since 1380; paraphrased)
    - Thread: same title, Steam EU5, 23 Nov 2025.
      https://steamcommunity.com/app/3450310/discussions/0/684112501455034928/
    - Replies: parliament reform only triggers before the Reformation with a burgher in the
      cabinet (paraphrased); "Hmm, this might actually be impossible."
    - Capability: connections.
    - Great answer: a list of every source of plutocracy with its own conditions and age limits.

12. "i was trying to embrace monarchy for 100 years. I now believe its impossible." "You cannot
    achieve 95% in aristocracy, best i could do is extend the limit to 65"
    - Thread: *Did you playtest changing government type?*, Steam EU5, 16 Nov 2025.
      https://steamcommunity.com/app/3450310/discussions/0/802331141614243487/
    - Replies: "Did you implement all poiicies and give all priviledges that help you tend
      towards Aristocracy?"; "Plutocracy is hard, but monarchy swap is extremely easy."
    - Capability: comparison (reforms/privileges that push the axis, side by side).
    - Great answer: comparison cards of monarchy vs republic reforms and their requirements.

13. "I can't remove this reform as France because there are blockers." "But these blockers
    aren't shown with the tooptip. It just says it's blocked."
    - Thread: *French 'Ancient Tax Law' reform*, Steam EU5, 7 Nov 2025.
      https://steamcommunity.com/app/3450310/discussions/0/667222425710356349/
    - Reply (15 Nov 2025, citing a data-mine): "In short, between 1420 and 1460 you need to
      have 25+ stability and not be at war" "and then you can get an event that gets rid of it."
      Later (4 Dec 2025): "it seemed they just updated so that you can remove it now".
    - Capability: exact conditions (hidden) + version difference.
    - Great answer: the reform's removal blockers and the event that removes it, per version.

14. "Legislative Efficiency ... is it just bad?"
    - Thread: same title, Steam EU5, 16 Nov 2025.
      https://steamcommunity.com/app/3450310/discussions/0/802331493180405516/
    - Replies: "Each percent of legislative efficiency reduces antagonism by that much
      percent."; "Legislative efficiency reduces antagonism, it doesn't tell you that in the
      tooltip"; "Oh thank you, I had no idea it even affected that."
    - Capability: connections (modifier -> every place it is used, incl. hidden ones).
    - Great answer: every script/define that reads legislative efficiency.

15. "It simply says 'No valid policies available'." (senior partner of a union cannot change
    centralization policies)
    - Thread: *Personal Union - Changing Centralization laws*, Steam EU5, 26 Nov 2025.
      https://steamcommunity.com/app/3450310/discussions/0/685238726928948642/
    - Replies: "Each unification policy needs the previous choice to be for unification not for
      federation"; "Something is wrong that you don't see the tooltip with the conditions."
    - Capability: exact conditions.
    - Great answer: the IO policy chain with each policy's prerequisite.

16. "there is nothing you can do to be able to pass reforms orther than stacking Authority"
    - Thread: *HRE Laws*, Steam EU5, 18 Feb 2026.
      https://steamcommunity.com/app/3450310/discussions/0/764059330564622262/
    - Replies quote Tinto Talks 98 and the 1.1.5 notes: AI vote reasons "adjusted", opinion
      weighting raised from 25% to 50%, "the -250 penalty to the great power check" removed.
    - Capability: version difference + defines (AI vote weights).
    - Great answer: the HRE law AI-acceptance weights in 1.1.5 vs 1.1.0.

17. "I am probably being stupid, but I can't get what exactly locks the religious law?" "It
    says the law is locked and I see no way to unlock it."
    - Thread: *HRE Religious Law*, Steam EU5, 9 Nov 2025.
      https://steamcommunity.com/app/3450310/discussions/0/667222787666052996/
    - Replies (2026): "You win religious war as protestant."; "The law was locked - and zero
      explantion of it."
    - Capability: exact conditions.
    - Great answer: the law's unlock trigger (War of Religions situation outcome).

### Theme: estates and privileges

18. "My nobles have 52% power and Im trying to revoke some privileges, but the stability cost
    is 181." "How can I lower the cost? The max stab i can hold is 100"
    - Thread: *How to revoke a noble estate privilege*, Steam EU5, 6 Nov 2025.
      https://steamcommunity.com/app/3450310/discussions/0/667222425710317970/
    - Reply: "the cost is only that high because that estate is already very powerful" ...
      "some techs also lower the cost".
    - Capability: exact numbers / defines (revoke-cost formula and its modifiers).
    - Great answer: the revoke-cost define with the developer comment, plus every advance,
      reform and value that carries a revoke-cost modifier.

19. "As title, would like to remove primacy of the nobility but the stability hit is so big so
    it would put me at -49 stability"
    - Thread: *Is there some non stability loosing way of removing privilegies to estates?*,
      Steam EU5, 8 Nov 2025.
      https://steamcommunity.com/app/3450310/discussions/0/667222787665988971/
    - Reply: "The less power they have the less stability cost to revoke."
    - Capability: exact numbers + exact effects ("what does this privilege change and what
      does it cost to revoke").
    - Great answer: the privilege card: effects, estate power it grants, revoke cost drivers.

20. Paradox forum (via search snippet): *UI not telling why estate privelege cant be removed -
    Byzantium* (bug report, Nov 2025). Player found the real blocker only by hovering
    "requirements not met" (paraphrased).
    https://forum.paradoxplaza.com/forum/threads/ui-not-telling-why-estate-privelege-cant-be-removed-byzantium.1868810/
    - Capability: exact conditions.

21. Paradox forum (via search snippet): *Too easy to dole out Estate Privileges* (Nov 2025).
    A poster contrasts EU4 with EU5 where requirements show as "has one or more blockers:
    never", making it hard to know the conditions without digging into game files
    (paraphrased around the quoted fragment).
    https://forum.paradoxplaza.com/forum/threads/too-easy-to-dole-out-estate-privileges.1867672/
    - Capability: exact conditions. Strong evidence line for the landing page if verified.

22. "Are estates underpowered, is it too easy and too attractive to increase crown power early
    on?" (title)
    - Thread: Steam EU5, 9 Jan 2026.
      https://steamcommunity.com/app/3450310/discussions/0/695375795020971806/
    - Replies compare privileges with numbers: clergy "up to 150% conversion speed", nobles
      "75% increased levy combat efficiency", a burgher privilege giving 0.0010 development
      with a "50% increase in crown power cost".
    - Capability: comparison (privilege cards side by side).

### Theme: control, proximity, supply (defines and connections)

23. "But in EU5? If i build roads it barely does anything"
    - Thread: *Can you help me to explain how to increase control and proximity?*, Steam EU5,
      30 Mar 2026. https://steamcommunity.com/app/3450310/discussions/0/796714053938486751/
    - Replies: "Getting a Core is easy, all you need is 51% of People there of Accepted Culture
      and above."; "It increases Control by 20% in the City you build it." (bailiff); "Local
      Govener act like a Second Main City, for Proximity with 80% instead of 100%."
    - Capability: defines/engine constants + connections ("how does control/proximity
      actually work").
    - Great answer: the proximity/control defines with developer comments, and the buildings,
      cabinet actions and advances that modify them.

24. "Why doesn't proximity spread by river?"
    - Thread: same title, Steam EU5, 10 Nov 2025.
      https://steamcommunity.com/app/3450310/discussions/0/667222787666173344/
    - Replies disagree: "river gives a discount. downstream is 20 and not sure on upstream."
      vs "downstream it reduces the proximity penalty by 30 per per tile. upstream, by 10."
    - Capability: defines (two players, two numbers; the file settles it).
    - Great answer: the exact river proximity-cost defines, by version.

25. "I have an army of 20k professional troops that require 10.36 food per day." (troops starve
    after 2-3 sea tiles although transports carry 206 food; paraphrased)
    - Thread: *Food supply*, Steam EU5, 3 Dec 2025.
      https://steamcommunity.com/app/3450310/discussions/0/685239361818639329/
    - Reply: "That's open water/ocean attrition."
    - Capability: defines ("what feeds into supply", ocean attrition constants).

26. "attrition has always been a monthly tick, it has never been tracked individually by army
    or movement duration." (reply) / OP: attrition now hits at the start of the month, 1% per
    month is too high (paraphrased)
    - Thread: *Stupid attrition of patch 1.2.**, Steam EU5, 13 May 2026.
      https://steamcommunity.com/app/3450310/discussions/0/840628131190577354/
    - Also: "On patch 1.2, supply line is bugged so army can't get food from occupied territory
      properly."
    - Capability: version difference (attrition/supply defines 1.1 vs 1.2).

27. "Has anyone tried the EXACT calculation? In the province where its suppose to add up every
    modifier ?" "Well it doesnt add up the actual amount of converted, at ALL."
    - Thread: *Cultural assimilation tooltip is lying to you !*, Steam EU5, 22 Nov 2025.
      https://steamcommunity.com/app/3450310/discussions/0/684112501454984840/
    - Replies: "the actual effect is divided among the number of locations in the province";
      "Tribesmen have 'assimilates and converts at 0% speed' in the tooltip."
    - Capability: exact numbers + connections (pop-type modifiers).

28. "I've got a few cultures that I want to add, but can't seem to find where in the culture UI
    I can do this?"
    - Thread: *Anyone know how to add an accepted culture?*, Steam EU5, 12 Nov 2025.
      https://steamcommunity.com/app/3450310/discussions/0/678482059259341390/
    - Replies disagree: "more than 2% of your population" vs "You meant to say 2.5%. And for
      tolerating you need 1%."
    - Capability: defines.

### Theme: advances, culture, institutions, casus belli

29. "When you playing as a nation with a culture with only a few bonuses like french," "how can
    you get the bonuses from english or spain?"
    - Thread: *HOW TO GET CULTURE BONUSES*, Steam EU5, 6 Dec 2025.
      https://steamcommunity.com/app/3450310/discussions/0/685239622575390075/
    - Capability: connections (culture -> its advances / unlocks). Direct match for "which
      advances does Ruthenian culture get".
    - Great answer: the culture document listing every advance, reform, building and unit it
      unlocks, with the unlock type.

30. "advances chart? I can't find one anywhere." "Specifically, I need to get paved roads."
    - Thread: same title, Steam EU5, 2 Dec 2025.
      https://steamcommunity.com/app/3450310/discussions/0/685239361818598206/
    - Capability: connections (what unlocks X; walk the advance tree backwards).

31. "After the age of discovery, the only advances that show up for me are the institutional
    advances," "the advances listed from choosing 'Administrative, Diplomatic or Military' are
    nowhere to be seen?"
    - Thread: *Not getting access to advances from age focus?*, Steam EU5, 19 Jan 2026.
      https://steamcommunity.com/app/3450310/discussions/0/742664495215757435/
    - Reply: "Techs that are focus/culture/religion/other will have an icon on their left,
      which will tell you why it is in the tree."
    - Capability: exact conditions (advance availability triggers).

32. "Is it truly just 100% random who discovers an institution first?" ... "what are the
    conditions?"
    - Thread: *what dictates the first country to get an institution?*, Steam EU5, 11 Nov 2025.
      https://steamcommunity.com/app/3450310/discussions/0/667222787666271643/
    - Reply: the tooltip shows "a percentage chance for it to spawn every month" and the
      requirements vanish once it has spawned (paraphrased).
    - Capability: exact conditions + defines (spawn weights).

33. "So the casus belli for religious war is no longer possible, says you need to have
    researched Deus Vault" "which was not a requirement before but thats not all..." "the Deus
    Vault tech seems to have disappeared from the tech tree lol"
    - Thread: *Can no longer do religious wars...*, Steam EU5, 20 Nov 2025.
      https://steamcommunity.com/app/3450310/discussions/0/684112192552921035/
    - Reply: "The CB being freely available to anyone from the start was a bug, it has been
      fixed now." "Deus Vult is part of the Renaissance Administrative Focus, and will not
      appear in the Advances tree" "if Administrative Focus is not picked."
    - Capability: version difference + connections (CB -> advance -> age focus).
    - Great answer: the CB's trigger diff between patches and the advance that gates it.

34. "Does anyone actually know yet how to unlock Anglicanism in EUV?"
    - Thread: *Anglicanism?*, Steam EU5, 11 Nov 2025.
      https://steamcommunity.com/app/3450310/discussions/0/667222787666218264/
    - Reply: "Event requirements are that you have a ruller who is male over 25, he has to be
      maried and have no male children." plus Reformation active and 1530-1560.
    - Capability: exact conditions (event trigger).

35. "What's the best way to increase prestige?" "I seem unable to overcome the prestige decay
    to make it to the 50 required to form a kingdom."
    - Thread: *Prestige?*, Steam EU5, 15 Nov 2025.
      https://steamcommunity.com/app/3450310/discussions/0/802331141614159599/
    - Capability: connections + defines (prestige decay constant and every prestige source).

36. "Do you unlock more cbs as the game goes on?" (title); reply: "You can see what cb will be
    unlocked on the tech ui."
    - Thread: Steam EU5, 12 Nov 2025.
      https://steamcommunity.com/app/3450310/discussions/0/678482059259324089/
    - Capability: connections (age/advance -> CBs).

### Theme: "did this change in the patch?" (version difference)

37. "Best way to integrate new lands in patch 1.2? (Given the 10-year cooldown on culture
    conversion)" (title); OP: the "Enforce Culture" vassal action now has a global 10-year
    cooldown (paraphrased).
    - Steam EU5, 17 May 2026.
      https://steamcommunity.com/app/3450310/discussions/0/840628406751216451/
    - Capability: version difference + defines.

38. "I stopped playing my ongoing games after the patch last night due to the trade maintenance
    issue." Reply: "pre patch they had demands just by being nobles, now they have to be nobles
    with money."
    - Thread: *Confusion around trade fix...*, Steam EU5, 18 Nov 2025 (1.0.5).
      https://steamcommunity.com/app/3450310/discussions/0/802331493180512461/
    - Capability: version difference (pop demand rules).

39. "As in title now my vassals are not loyal because of -20 centralisation factor."
    - Thread: *1.08 change vassal loyalty*, Steam EU5, 2 Dec 2025.
      https://steamcommunity.com/app/3450310/discussions/0/685239206088351605/
    - Capability: version difference + exact numbers (loyalty breakdown).

40. "As per the title, i can't create a colonial nation" ... Reply: "In my first runs I was able
    to make Madeira a colonial nation." "After one of patches I am no longer able to do it."
    - Thread: *Why do I cannot create a colonial nation?*, Steam EU5, 27 Nov 2025.
      https://steamcommunity.com/app/3450310/discussions/0/685238726929028980/
    - Capability: version difference + exact conditions (different continent, no land link).

---

## Hearts of Iron IV

### Theme: focus requirements, bypasses, DLC-conditional script

1. "I´m looking for a guide for Eva Braun and all of these guides on youtube have another Focus
   Tree 'Anschluss' than me." "In all guides, it says '24 times bigger' but I don´t have this
   line." "I need to have 500k units AND 50k guns in my army."
   - Thread: *Question about Anschluss*, Steam HOI4, 15 Nov 2024 (Gotterdammerung launch week).
     https://steamcommunity.com/app/394360/discussions/0/7074686732306750064/
   - Replies: "The 500k requirement was the old one."; a user pastes the script:
     `IF = { limit = { has_dlc = "Gotterdammerung" }` ... else manpower > 499,999 and > 50
     infantry equipment; OP: "That´s what I mean with 'guide is 6 hours old'".
   - Capability: version difference (DLC-conditional requirements) + exact conditions.
   - Great answer: the focus's `available` block showing both branches of the has_dlc check.

2. "What are the differences between the left and right paths of the economy in the new German
   focus tree?" (title; OP guesses left = civilian factories, right = military)
   - Steam HOI4, 23 Mar 2025.
     https://steamcommunity.com/app/394360/discussions/0/601899704908834250/
   - Replies compare: left path starts with a big consumer-goods penalty from paying off MEFO
     bills, right path is faster but MEFO bills build up until collapse at 100% (paraphrased).
   - Capability: comparison (two focus branches as side-by-side cards).

3. France fascist path: cannot select "Establish Spheres of Influence" because it requires a
   fascist Germany, which went monarchist (paraphrased).
   - Thread: *France focus tree issue*, Steam HOI4, 19 Jun 2022.
     https://steamcommunity.com/app/394360/discussions/0/4932019356823321504/
   - Reply: "You can try poking around in the game files to mess with the requirements".
   - Capability: exact conditions (hidden cross-country requirement).

4. "tell me why Owning Danzig," "Poznan and the wierd state don't bypass that focus"
   - Thread: *German Focus Bypasses*, Steam HOI4, 6 Jun 2018.
     https://steamcommunity.com/app/394360/discussions/0/1697175413668154011/
   - Reply: "When you're at war with Poland, you will bypass the ''Danzig or war'' Focus."
   - Capability: exact conditions (bypass block vs available block).

5. "Is it possible to get activated all 3 doctrine trees for special forces?"
   - Thread: *Special forces?*, Steam HOI4, 17 Jul 2025.
     https://steamcommunity.com/app/394360/discussions/0/601910081412507901/
   - Replies: one pastes the `diversify_special_forces` decision from the files and notes a
     missing "or" bug ("Dont know if they ever fixed this bug."); another (5 May 2026): "If the
     wiki is right why only 3 countries can get a 3. point?"
   - Capability: exact conditions + version difference.

6. "Can I change from 'undisturbed economy' as fascist USA?" "Last game I was stuck on that
   stupid economy law and couldnt mobilize my country. How do I get rid of it?"
   - Steam HOI4, 7 Jan 2024.
     https://steamcommunity.com/app/394360/discussions/0/4030224882301076222/
   - Reply: "Fascist side can, communist side can't. Don't take any focus with the red text
     saying it leads to civil war."
   - Capability: connections (law -> focuses/events that unlock changing it).

7. "fighter aircraft program that gives -25% cost production to fighters" (how to get the
   German national spirit); follow-up "what need to take that decision" went unanswered.
   - Thread: *Germany how to get national spirit*, Steam HOI4, 3 Jan 2021.
     https://steamcommunity.com/app/394360/discussions/0/3004430047208962375/
   - Capability: exact conditions (decision trigger -> spirit).

8. "I got the Cradle of Civilization acheivement recently, but the Graveyard of Empires
   acheivement hasn't popped," "despite literally owning all the cores of Iran, Iraq,
   Afghanistan, Raj, and Burma for good measure."
   - Thread: *Grave of Empires Acheivement is Broken.*, Steam HOI4, 16 Mar 2025 (GoE DLC).
     https://steamcommunity.com/app/394360/discussions/0/640179666902079334/
   - Reply: "I got it by annexing them It dosnt work if you just cap them."
   - Capability: exact conditions (achievement trigger text).

### Theme: what does this spirit / law actually do

9. "What is the Nine Power Treaty?" "More specifically, what does it do?" "I've looked it up and
   couldn't find any thing it affects." "The only thing I've found is the national focus that
   removes it."
   - Steam HOI4, 1 Oct 2018.
     https://steamcommunity.com/app/394360/discussions/0/2747650363467470910/
   - Reply (wiki quote): "China is restricted to Free Trade,".
   - Capability: exact effects + connections (spirit -> law lock -> focus that removes it).

10. "Not complaining (or am I?) but there is something I STILL don't understand." (what the
    "country" line in the autonomy score is and why it changes)
    - Thread: *The mysteries of the autonomy score*, Steam HOI4, 6 Feb 2024.
      https://steamcommunity.com/app/394360/discussions/0/4202490257586780206/
    - Reply: the "Princely States" spirit "reduces your autonomy by 0.1 every day;" and the
      "Provincial Elections" focus raises that to 0.4 per day (paraphrased).
    - Capability: connections + exact numbers.

11. "What is the actual point of trade law....for instance free trade if im giving up 80
    percent of my civilian factories" "...for 15 perccent contrution increase"
    - Thread: *Trade Law help*, Steam HOI4, 9 Jul 2016.
      https://steamcommunity.com/app/394360/discussions/0/365172547945195238/
    - Replies: "You get a 10% research bonus if you put free trade, which is massive."
    - Capability: comparison (trade laws side by side).

12. Consumer goods floor: OP found reductions stop at a 10% minimum which tooltips never
    mention; cited game files and a Paradox thread for the "0.1" cap; notes Italian reduction
    focuses expire after 730 days (paraphrased).
    - Thread: *Consumer Goods Minimum is capped at 10%*, Steam HOI4, 4 Sep 2024.
      https://steamcommunity.com/app/394360/discussions/0/4751948599936684948/
    - Capability: defines/engine constants.

### Theme: defines and engine constants

13. "What there are rules?" "When I can justify war goals in 10 days?"
    - Thread: *justifying a war goals time*, Steam HOI4, 23 Apr 2017.
      https://steamcommunity.com/app/394360/discussions/0/1319961868327189881/
    - Replies: "I know that the base minimum Justifying time is 10 days"; "World Tension;
      reduces the time (and cost) of justifying of wargoals by up to 75% at 100% World
      Tension."; "Fascism; Time to justify war when at war with major power: -80%."
    - Capability: defines.

14. "I tried playing as Japan, but I kept losing my justification for war."
    - Thread: *How long does justification for war last?*, Steam HOI4, 19 Jun 2016.
      https://steamcommunity.com/app/394360/discussions/0/358415206092626401/
    - Reply: "the justification only last for about 2 months I belive"
    - Capability: defines (expiry days).

15. "Does stability has cap if you are at war?" "I am at war at can't get stability over 85"
    - Thread: *Stability has cap at 85 noobs*, Steam HOI4, 7 Jul 2018.
      https://steamcommunity.com/app/394360/discussions/0/1729828401701270008/
    - Replies disagree ("Nope" vs "+15% ... at war it's -30%, so your stability cap wil be 85%").
    - Capability: defines / exact numbers.

16. "Before I try for the fourth time I was wondering if the amount of the country under
    anti-Stalin control is a factor in determining success."
    - Thread: *Soviet Right Bloodless Coup*, Steam HOI4, 15 Dec 2021.
      https://steamcommunity.com/app/394360/discussions/0/4739473745767237994/
    - Reply: "Flat 50% chance + 30% if you have NKVD support."
    - Capability: exact numbers (event option weights).

### Theme: doctrine comparison

17. "So what do you guys think of GBP, does it seem useless to you too or is it good for
    specific nations?"
    - Thread: *Is there any reason to not choose Superior Firepower over GBP/Mass Assault
      doctrines?*, Steam HOI4, 21 Feb 2018.
      https://steamcommunity.com/app/394360/discussions/0/1693788202023669553/
    - Reply: "At maximum planning, Grand Battleplan does have better soft and hard attack, as
      well as breakthrough"
    - Capability: comparison (doctrine cards with exact modifiers).

### Theme: recent DLC version changes

18. Thunder at Our Gates 1.19.1 patch notes (Paradox forum, via search snippet, Jun 2026):
    Indonesia's "Economic Integration" focus now needs 50 factories of any type; Australia's
    "Phosphate Commission" now requires owning Nauru; several Australian focus durations cut
    from 70 to 35 days (paraphrased).
    https://forum.paradoxplaza.com/forum/threads/thunder-at-our-gates-patch-1-19-1.1928898/
    - Capability: version difference.

19. "To everyone considering getting the new South America DLC..." (Trial of Allegiance, Mar
    2024); reply: "you can get the focus trees for free just by deleting the line called has_dlc"
    - Steam HOI4, 7 Mar 2024.
      https://steamcommunity.com/app/394360/discussions/0/4286935452900211249/
    - Capability: evidence that focus availability is DLC-conditional script.

---

## Civilization VII

### Theme: civ unlock conditions

1. "So you have to unlock new Civilizations EVERY GAME?" (title) and "Are civilization unlocks
   permanent?" (title)
   - Steam Civ 7, Feb 2025.
     https://steamcommunity.com/app/1295660/discussions/0/598519418380638321/
     https://steamcommunity.com/app/1295660/discussions/0/598519173680764658/
   - Capability: exact conditions.

2. "You have unlocked Great Britain. Sike." (title; why the game announces unlocked civs you
   cannot select, 15 Mar 2025)
   - Steam Civ 7. https://steamcommunity.com/app/1295660/discussions/0/569247849657738163/
   - Replies: three routes (Ada Lovelace in Antiquity, two Fleet Commanders in Exploration,
     Rome in Antiquity); the Fleet Commander route reported buggy (paraphrased).
   - Capability: exact conditions.
   - Great answer: the unlock requirement block for Great Britain and which routes were
     changed in which patch.

3. "then I find out it is purely random for me to have 3 camels to improve." "Then I have
   restart the game again and again to at least see some camels around my capital city."
   - Thread: *More reliable ways to unlock civs*, Steam Civ 7 feedback, 27 Feb 2025.
     https://steamcommunity.com/app/1295660/discussions/2/600771622034520990/
   - Capability: exact conditions (Abbasid: "Improve three Camel resources.").

4. "I am at the Exploration Age screen. I had played Scientific (Franklin) in the Antiquity
   Age." "Why do I see no choices to continue with a Scientific Civ as they are locked."
   - CivFanatics, *Going Into Exploration Age - Why No Sciencific Civ & Locked Civs*, 13 Oct 2025.
     https://forums.civfanatics.com/threads/going-into-exploration-age-why-no-sciencific-civ-locked-civs.700225/
   - Reply: "You have to unlock these through various ways usually involving doing something
     3 times."
   - Capability: exact conditions.

5. Tides of Power unlocks (CivFanatics leader threads, via search snippet, Dec 2025):
   "Republic of Pirates (otherwise unlocked by plundering 2 Trade Routes)"; "Iceland (otherwise
   unlocked by Coastal Raiding 5 times or being the first to discover a Natural Wonder)".
   https://forums.civfanatics.com/threads/leader-discussion-sayyida-al-hurra.700973/
   https://forums.civfanatics.com/threads/leader-discussion-isabella.699562/
   - Capability: exact conditions (new DLC content, thin wiki).

6. "I feel stupid, I tried to play this for first time with Cartage" (Sayyida al Hurra's
   ability: ships on districts did not raise influence)
   - Thread: *Sayyida al Hurra - just how?*, Steam Civ 7, 9 Jan 2026.
     https://steamcommunity.com/app/1295660/discussions/0/689746295486789276/
   - Replies: "You need to place a naval unit on the sea district or improvement."; "The UI
     needs to be refreshed, after you move the ship onto a tile to see the difference."
   - Capability: exact effects (leader ability text vs rule).

### Theme: traditions, civics, policies, leader abilities (what does it actually do)

7. "So this Khmer tradition 'Kambu-Mera' SAYS it gives '+100% to food and happiness maintenance
   to specialists'" ... "it DOES NOT what it says. Happiness is only reduced by 50%."
   - Thread: *Khmer Tradition "Kambu-Mera": Why so strong?*, Steam Civ 7, 10 Mar 2025.
     https://steamcommunity.com/app/1295660/discussions/0/598520761350685490/
   - Replies: "The tradition actually reduces the happiness cost of specialists just by 50%
     (food by 100%!)"; "It is just a plain wrong description of what it does."
   - Capability: exact numbers (modifier definition vs tooltip wording).
   - Great answer: the tradition's modifier entries from the data files.

8. "Is that an automatic bonus I get for the rest of the age or does it need to be slotted into
   a civic policy like in Civ 6?" (Greek Ekklesia tier 2)
   - Thread: *Do unique civics need to be slotted?*, Steam Civ 7, 31 Jan 2025.
     https://steamcommunity.com/app/1295660/discussions/0/591761879137845834
   - Reply: "the policies/traditions will have that quill pen symbol, and the passives will
     have the plus sign symbol."
   - Capability: exact effects.

9. "Can someone explain how Policies and Traditions work?"
   - CivFanatics, *How do Policies and Traditions work?*, 23 Oct 2024 (pre-release).
     https://forums.civfanatics.com/threads/how-do-policies-and-traditions-work.692738/
   - Capability: exact effects / comparison (policy cards vs traditions).

10. "Unique improvements say they don't remove the warehouse bonus too?"
    - CivFanatics, *Can someone explain warehouses to me?*, 12 Feb 2025.
      https://forums.civfanatics.com/threads/can-someone-explain-warehouses-to-me.695259/
    - Capability: exact effects.

11. Leader + civ bonuses: do they stack? (OP, paraphrased) -> "Yes, they do stack."
    - Thread: *Starting a new game, already confused!*, Steam Civ 7, 6 Feb 2025.
      https://steamcommunity.com/app/1295660/discussions/0/591762563949158758/
    - Capability: connections.

12. Gilgamesh's ability "which is written as a three-parter but is pretty blatantly a five:";
    "only be in effect if he's in exactly one alliance"
    - CivFanatics, *Leader Discussion - Gilgamesh*, 3 Feb 2026.
      https://forums.civfanatics.com/threads/leader-discussion-gilgamesh.701967/
    - Capability: exact effects (ability text vs actual modifiers).

13. "The 2 domination score that Tecumseh earns from city-state suzerainty stacks across all of
    the ages."
    - CivFanatics, *Leader Discussion - Tecumseh*, 22 Jul 2026.
      https://forums.civfanatics.com/threads/leader-discussion-tecumseh.700358/
    - Capability: exact effects (does it stack / persist across ages).

### Theme: yields, adjacency, specialists (exact numbers; patched repeatedly)

14. "Sorry to ask such a basic question but I can't figure out what good specialists are." ...
    "when I add a specialists it doesn't seem to add anything to the city, but it typically will
    subtract happiness and coin. What am I missing?"
    - CivFanatics, *Specialists*, 19 Jun 2026.
      https://forums.civfanatics.com/threads/specialists.703696/
    - Reply: "wasn't a fan of the changes to Specialists in 1.4." Related 1.4.0 note:
      "Specialists no longer have a base Yield (Previously: 2 Science and Culture)." and they
      now give "100% of their tile's Adjacency Yields" (previously 50%).
    - Capability: version difference + exact numbers.
    - Great answer: specialist yield rules in 1.3 vs 1.4, side by side.

15. "My best tile right now is 23/40 according to the game. 50% into exploration age."
    - CivFanatics, *i find it hard to get to the 40+ per tile in exploration age.*, 20 Apr 2025.
      https://forums.civfanatics.com/threads/i-find-it-hard-to-get-to-the-40-per-tile-in-exploration-age.697682/
    - Replies: "Specialist get a bonus .5 Yield for each adjacency bonus."; "all other buildings
      lose their adjacency benefits upon age transition."; "It wasn't great until an update a
      couple days ago changed the growth curve."
    - Capability: exact numbers + version difference.

16. "Highest quantity of a single yield on one tile?" (title)
    - CivFanatics, 31 Oct 2025.
      https://forums.civfanatics.com/threads/highest-quantity-of-a-single-yield-on-one-tile.700489/
    - Replies: "All of the 6 tiles should be Mountains...because they will give 2 adjacencies";
      "Add Machu Picchu, which by itself grants +1 adjacency bonus". (1.4.0 later limited Machu
      Pikchu / Brihadeeswarar adjacency to "Buildings in this Settlement".)
    - Capability: exact numbers + connections + version difference.

17. "There is some weird mechanic where roads that go through your cities don't count, only
    roads between the cities." (reply) / OP: two cities show "Settlement not connected to your
    empire's trade network" despite roads (paraphrased)
    - CivFanatics, 22 Feb 2025.
      https://forums.civfanatics.com/threads/settlement-not-connected-to-your-empires-trade-network.695944/
    - Reply: Civilopedia entries on this are "absolutely useless".
    - Capability: exact conditions (connection rule).

18. "So obviously a 10% increase in cost per additional city is pretty big" ... "the 5% increase
    per building (excluding warehouse buddings)" ... "Also does this apply to civ unique
    buildings?"
    - CivFanatics, *Question about changes to building production/gold cost?*, 14 Nov 2025.
      https://forums.civfanatics.com/threads/question-about-changes-to-building-production-gold-cost.700667/
    - Capability: version difference + exact numbers.

### Theme: legacy paths / triumphs and patch churn (version difference)

19. "does the Exploration economic path seem much, much harder after the last couple of patches?"
    - CivFanatics, 1 May 2025.
      https://forums.civfanatics.com/threads/does-exploration-economic-legacy-path-seem-difficult-to-impossible-after-the-past-couple-of-patches.697898/
    - Replies: "allowing treasure resources to spawn on both hemispheres messed with the
      distribution logic"; "Initially Continents+ was the easiest map to get economic legacy
      path" "After two patches, it's the toughest map."
    - Capability: version difference.

20. What happens if you don't follow any legacy path, and how do you accumulate points?
    (paraphrased OP question list)
    - Steam Civ 7, *There are some mechanics I still can't understand..*, 23 Apr 2025.
      https://steamcommunity.com/app/1295660/discussions/0/600776571073090204/
    - Capability: connections (legacy -> attributes -> golden ages).

21. 1.4.0 "Test of Time" (19 May 2026): "the new Triumphs system replacing Legacy Paths";
    "Introduced Time-Tested civs, adding the option to start and stay as any civ."; "Designed
    New Unique Abilities for every civilization". Replies: "Is there a list of the changes to
    the civs anywhere?"; "They still do not tell you what yields you get when choosing a town
    focus."; "No policy yield previews any more".
    - CivFanatics. https://forums.civfanatics.com/threads/civilization-vii-update-1-4-0-test-of-time-may-19-2026.703352/
    - Capability: version difference (whole systems replaced; patch notes incomplete).

22. 1.1.1 (25 Mar 2025) numeric changes: "Factory Cost increased from 600 to 1400." "Port Cost
    increased from 550 to 1200." "Scorched Earth Policy changed from '+5 Combat Strength for
    all Units when attacking' to '+3 Combat Strength for all Units when attacking.'" "Legion
    Unit changed from '+2 Combat Strength for every Tradition in the Government' to '+1 ...'"
    Reply: "Wow, big nerf to Hawaii."
    - CivFanatics. https://forums.civfanatics.com/threads/update-1-1-1-patch-notes-march-25-2025.697098/
    - Capability: version difference (exact old vs new values).

23. "We have had a number of patches come lately that have no patch notes indicating what was
    fixed. I have looked around the 2k site and don't see any either, am i missing something?"
    - Steam Civ 7, *Patch Notes?*, 17 Feb 2025.
      https://steamcommunity.com/app/1295660/discussions/0/570371410647596354/
    - Capability: version difference (evidence: players cannot tell what changed).

---

## "The wiki / guide / video is outdated" quotes (evidence for "always current")

1. EU5, Steam, 17 Dec 2025: "Wiki says 'If not Flag of Byzantium, then Byzantium does not
   exist' In game says that it should not exist?" ... "they apparently fixed the triggers but
   _not_ the country rank."
   https://steamcommunity.com/app/3450310/discussions/0/684114729914881441/

2. EU5, Steam, 12 Dec 2025 (*Poland help*): "sucks wiki ain't up yet bc I wish there was a
   place to just see all the events and requirements lmao" / "The wiki IS up..." "Not sure how
   complete or accurate it is but it's there." / "It's been nearly a month and a half and the
   link to the 'Ottoman content' page from the main" [Ottomans page is still a dead end;
   Brandenburg, Scotland, Papal States have no pages - paraphrased continuation].
   https://steamcommunity.com/app/3450310/discussions/0/691995483855452220/

3. EU5, Steam, 14-15 Jan 2026 (*New to the game, Stuck*): "we cant really look them up on the
   unfinished wiki either" / "YouTube videos already outdated because every patch they make
   huge meta changes."
   https://steamcommunity.com/app/3450310/discussions/0/682991447917467869/

4. EU5, Steam guide *How to get Hohenzollern as Brandenburg*, author note 16 May 2026: "THIS
   GUIDE IS NOW MOSTLY OUTDATED. MOST OF THE EVENT ids WERE CHANGED AND NO LONGER WORK LIKE
   THIS." / comment: "Welp, they made this guide mostly pointless." / 23 Dec 2025: "in my
   current run due to the 1.0.10 -> bohemia has lost the emperor titel before i get my
   hohenzollern."
   https://steamcommunity.com/sharedfiles/filedetails/?id=3602897776

5. EU5, Steam, 7 Nov 2025: "these blockers aren't shown with the tooptip. It just says it's
   blocked." (answer came from a data-mine, and a later patch changed it again).
   https://steamcommunity.com/app/3450310/discussions/0/667222425710356349/

6. HOI4, Steam, 15-16 Nov 2024 (*Question about Anschluss*): "In all guides, it says '24 times
   bigger' but I don´t have this line." / "That´s what I mean with 'guide is 6 hours old'"
   https://steamcommunity.com/app/394360/discussions/0/7074686732306750064/

7. HOI4, Steam, 19 Nov 2024 (*Devs please update the wiki*): "Lots of newer content is missing,
   when i started playing it was a great resource for learning," "but it's really falling
   behind." "Especially given as so much community content is out of date" / reply: "It took
   an entire DLC before the aircraft designer was put into the wiki so I wouldn't hold my
   breath for this." / "The game just needs a reliable manual"
   https://steamcommunity.com/app/394360/discussions/0/4625854789815643849/

8. HOI4, Paradox forum *Hearts of Iron 4 Wiki* thread (via search snippet, 2023-2024):
   commenters report most of the wiki stuck at version 1.9 or earlier with only a few pages
   updated, and a beginner's guide and air-missions page still showing pre-1.15 figures
   (paraphrased). https://forum.paradoxplaza.com/forum/threads/hearts-of-iron-4-wiki.750989/page-49

9. HOI4, Steam, 5 May 2026 (*Special forces?*): "If the wiki is right why only 3 countries can
   get a 3. point?" https://steamcommunity.com/app/394360/discussions/0/601910081412507901/

10. HOI4, Steam guide *Hearts of Iron 4 - Historical Focus Paths* (via search snippet; page
    rate-limited): marked "Last Fully Updated: Update v1.15.0", author notes a lot may be
    outdated; a related listing is marked outdated since Graveyard of Empires because of
    changes to the British Raj (paraphrased).
    https://steamcommunity.com/sharedfiles/filedetails/?id=1324609784

11. Civ 7, Steam, 10 Mar 2025 (*Kambu-Mera*): "It is just a plain wrong description of what it
    does." https://steamcommunity.com/app/1295660/discussions/0/598520761350685490/

12. Civ 7, CivFanatics, 23 Feb 2025: Civilopedia entries on trade-network connection are
    "absolutely useless" (PatrickTheProgrammer).
    https://forums.civfanatics.com/threads/settlement-not-connected-to-your-empires-trade-network.695944/

13. Civ 7, CivFanatics, 19 May 2026 (1.4.0 thread): "Is there a list of the changes to the civs
    anywhere?" / "They still do not tell you what yields you get when choosing a town focus."
    https://forums.civfanatics.com/threads/civilization-vii-update-1-4-0-test-of-time-may-19-2026.703352/

14. Civ 7, Steam guide *A Legacy Written in Gold* (via search snippet; page rate-limited): the
    guide says of itself that certain aspects were changed in the most recent patch, such as
    making explorers more expensive (paraphrased).
    https://steamcommunity.com/sharedfiles/filedetails/?id=3427558392

15. Civ 7, Steam, 17 Feb 2025: "We have had a number of patches come lately that have no patch
    notes indicating what was fixed."
    https://steamcommunity.com/app/1295660/discussions/0/570371410647596354/

---

## Hero shortlist (12), condensed to under 14 words, one capability each

| # | Game | Hero question (condensed) | Capability | Source item |
|---|------|---------------------------|------------|-------------|
| 1 | EU5 | What exactly do I need to form Prussia? | exact conditions | EU5 #1 ("36 out of 33 locations ... still can't form") |
| 2 | EU5 | Which hidden blockers stop me removing France's Ancient Tax Law? | exact conditions (hidden) | EU5 #13 |
| 3 | EU5 | Why does revoking Primacy of the Nobility cost 181 stability? | exact numbers / defines | EU5 #18, #19 |
| 4 | EU5 | What does Legislative Efficiency actually affect? | connections | EU5 #14 |
| 5 | EU5 | Does proximity follow rivers? Downstream 20 or 30? | defines/engine constants | EU5 #24 |
| 6 | EU5 | Could Byzantium form Rome in 1.0.10? And in 1.1? | version difference | EU5 #2 |
| 7 | EU5 | Which advances does my culture unlock that English or Spanish don't? | connections | EU5 #29 |
| 8 | HOI4 | What does Anschluss require with, and without, Gotterdammerung? | version difference (DLC) | HOI4 #1 |
| 9 | HOI4 | German economy: left path vs right path, exactly? | comparison | HOI4 #2 |
| 10 | HOI4 | What does the Nine Power Treaty spirit actually do? | exact effects | HOI4 #9 |
| 11 | Civ 7 | Does Kambu-Mera really cut specialist upkeep by 100%? | exact numbers vs tooltip | Civ 7 #7 |
| 12 | Civ 7 | What changed for specialists between 1.3 and 1.4.0? | version difference | Civ 7 #14 |

Alternates: "What unlocks Great Britain in the Exploration Age?" (Civ 7 #2, exact conditions);
"Base days to justify a war goal, and what cuts it?" (HOI4 #13, defines); "Why is the
religious-war CB now locked behind Deus Vult?" (EU5 #33, version + connections); "Which
reforms open up if I go republic instead of monarchy?" (EU5 #12, comparison).

---

## Recurring confusion patterns (landing-page copy angles)

EU5
- "Requirements not met" with no requirement shown. Reforms, laws, privileges, PU policies
  and formables all hide blockers behind a red X (#7, #13, #15, #17, #20, #21). Players answer
  each other by opening the game files ("From the game files, these are the requirements").
- Numbers argued from memory: river proximity 20 vs 30, accepted-culture 2% vs 2.5%, revoke
  cost "some techs also lower the cost". The defines settle it.
- Every answer ends with "that may have changed": 1.0.5 pop demand, 1.0.8 vassal loyalty,
  1.0.10 Prussia capital, 1.1.5 HRE votes, 1.2 attrition and the 10-year Enforce Culture
  cooldown, 1.4 daily tick. Guides self-declare "MOSTLY OUTDATED" within months.
- Culture/advance connections are opaque: "which culture gets which bonus", "what unlocks
  paved roads", "why did Deus Vult vanish from my tree".

HOI4
- The same focus has different requirements depending on `has_dlc`, so a YouTube guide can be
  "6 hours old" and still wrong for your install (#1, #19).
- Hidden caps and floors tooltips never mention: 10% consumer-goods floor, 85 stability at
  war, 10-day justify minimum, 2-month justification expiry (#12-#15).
- "What does this spirit/law actually do" is scattered across focuses, decisions and laws
  (#6, #7, #9, #10); the removing focus is easier to find than the effect.
- The community wiki is years behind (stuck on 1.9, "took an entire DLC" to document the
  aircraft designer), and players openly ask for "a reliable manual".

Civ 7
- Tooltip text that does not match the rule: Kambu-Mera "+100%" is 50%, Gilgamesh "written as
  a three-parter but is pretty blatantly a five", Sayyida's ships only count on sea
  districts (#6, #7, #12).
- Unlock conditions are findable only via the lock icon; players hand-compile lists that go
  stale, and the game announces unlocks you cannot pick (#2, #3, #4, #5).
- Patches rewrite whole systems (Legacy Paths -> Triumphs, specialists 50% -> 100%, factory
  cost 600 -> 1400) and patch notes are incomplete ("Is there a list of the changes to the
  civs anywhere?"), so any guide older than the last update is suspect (#14, #18, #21-#23).
- Civilopedia described as "barren" / "absolutely useless" for mechanics like trade-network
  connection (#17).
