// Behaviour for the public site pages, which are plain controller views with no
// LiveView: the header's look over dark bands, the hero's example chats,
// scroll-spy for the design system's left nav, disclosure toggles, copy buttons
// and the visual-only tab strips on /design.

// The site header is transparent over a dark band at the top of the page and
// turns into a frosted bar once the page scrolls. Its `data-theme` is "dark"
// while the header's middle sits over an element with `data-header-dark`.
function headerTheme() {
  const header = document.querySelector("[data-site-header]")
  if (!header) return
  const bands = Array.from(document.querySelectorAll("[data-header-dark]"))
  let frame = null
  const update = () => {
    frame = null
    const mid = header.offsetHeight / 2
    const dark = bands.some((band) => {
      const rect = band.getBoundingClientRect()
      return rect.top <= mid && rect.bottom > mid
    })
    header.dataset.theme = dark ? "dark" : "light"
    header.toggleAttribute("data-scrolled", window.scrollY > 8)
  }
  const schedule = () => {
    if (frame === null) frame = requestAnimationFrame(update)
  }
  window.addEventListener("scroll", schedule, {passive: true})
  window.addEventListener("resize", schedule)
  update()
}

function scrollSpy() {
  const nav = document.querySelector("[data-spy-nav]")
  if (!nav) return
  const links = Array.from(nav.querySelectorAll('a[href^="#"]'))
  const byId = new Map(links.map((a) => [a.getAttribute("href").slice(1), a]))
  const targets = Array.from(byId.keys())
    .map((id) => document.getElementById(id))
    .filter(Boolean)
  if (targets.length === 0) return

  let current = null
  const setCurrent = (id) => {
    if (current === id) return
    current = id
    links.forEach((a) => a.removeAttribute("aria-current"))
    const link = byId.get(id)
    if (link) {
      link.setAttribute("aria-current", "true")
      link.scrollIntoView({block: "nearest", inline: "nearest"})
    }
  }
  // The current section is the last one whose top has passed a line a third
  // of the way down the viewport.
  const update = () => {
    const line = window.innerHeight * 0.3
    let best = targets[0]
    for (const t of targets) {
      if (t.getBoundingClientRect().top <= line) best = t
      else break
    }
    setCurrent(best.id)
  }
  window.addEventListener("scroll", update, {passive: true})
  window.addEventListener("resize", update)
  update()
}

function toggles() {
  document.querySelectorAll("[data-toggle]").forEach((button) => {
    const target = document.getElementById(button.dataset.toggle)
    if (!target) return
    button.addEventListener("click", () => {
      const open = target.classList.toggle("hidden") === false
      button.setAttribute("aria-expanded", String(open))
    })
  })
  document.querySelectorAll("[data-dismiss]").forEach((button) => {
    button.addEventListener("click", () => {
      const target = button.closest(button.dataset.dismiss || "[role=alert], [role=status]")
      if (target) target.remove()
    })
  })
}

function copyButtons() {
  document.querySelectorAll("[data-copy]").forEach((button) => {
    const label = button.querySelector("[data-copy-label]") || button
    const original = label.textContent
    button.addEventListener("click", async () => {
      try {
        await navigator.clipboard.writeText(button.dataset.copy)
        label.textContent = "Copied"
        setTimeout(() => (label.textContent = original), 1500)
      } catch (_e) {
        label.textContent = "Copy failed"
        setTimeout(() => (label.textContent = original), 1500)
      }
    })
  })
}

// The hero's example chats: separate exchanges, several per game, on a stage of
// fixed height so the page never reflows. An exchange plays in (question, typing
// dots, answer), stays for the dwell, then the next one crossfades in. The game
// chips and the dots jump, and a click locks the cycle to that game. The cycle
// pauses while the stage is hovered, focused or off screen; under reduced
// motion nothing plays and each exchange is shown whole.
function chatDemo() {
  const root = document.querySelector("[data-chat-demo]")
  if (!root) return
  const chats = Array.from(root.querySelectorAll("[data-chat]"))
  if (chats.length === 0) return
  const tabs = Array.from(root.querySelectorAll("[data-chat-tab]"))
  const dots = Array.from(root.querySelectorAll("[data-chat-dot]"))
  const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches
  const DWELL = 7000
  root.style.setProperty("--dwell", `${DWELL}ms`)

  let index = 0
  let locked = null
  let visible = false
  let hovered = false
  let steps = []
  let dwell = null
  let startedAt = 0
  let remaining = DWELL

  const pool = () => (locked ? chats.filter((c) => c.dataset.chatGame === locked) : chats)
  const next = () => {
    const list = pool()
    return chats.indexOf(list[(list.indexOf(chats[index]) + 1) % list.length])
  }
  const stopDwell = () => {
    if (!dwell) return
    clearTimeout(dwell)
    dwell = null
    remaining = Math.max(0, remaining - (Date.now() - startedAt))
  }
  const startDwell = () => {
    if (dwell || reduced || pool().length < 2) return
    startedAt = Date.now()
    dwell = setTimeout(() => {
      dwell = null
      show(next())
    }, remaining)
  }
  // The dwell timer and the dot's fill pause and resume together.
  const sync = () => {
    const paused = !visible || hovered
    root.toggleAttribute("data-paused", paused)
    if (paused) stopDwell()
    else startDwell()
  }

  const show = (i) => {
    steps.forEach(clearTimeout)
    steps = []
    stopDwell()
    remaining = DWELL
    index = i
    const chat = chats[i]
    const game = chat.dataset.chatGame
    chats.forEach((c) => {
      const on = c === chat
      c.toggleAttribute("data-active", on)
      c.setAttribute("aria-hidden", String(!on))
    })
    tabs.forEach((t) => t.setAttribute("aria-selected", String(t.dataset.chatTab === game)))
    dots.forEach((d) => {
      d.classList.toggle("hidden", d.dataset.chatGame !== game)
      d.toggleAttribute("data-active", d.dataset.chatDot === String(i))
    })
    const parts = Array.from(chat.querySelectorAll("[data-chat-step]"))
    const typing = chat.querySelector("[data-chat-typing]")
    typing?.removeAttribute("data-shown")
    // Reset without a fade-out, then play the parts in.
    parts.forEach((p) => {
      p.style.transition = "none"
      p.removeAttribute("data-shown")
    })
    void chat.offsetWidth
    parts.forEach((p) => (p.style.transition = ""))
    if (reduced) {
      parts.forEach((p) => p.setAttribute("data-shown", ""))
    } else {
      const at = (ms, fn) => steps.push(setTimeout(fn, ms))
      at(50, () => parts[0]?.setAttribute("data-shown", ""))
      at(700, () => typing?.setAttribute("data-shown", ""))
      at(1800, () => {
        typing?.removeAttribute("data-shown")
        parts.slice(1).forEach((p) => p.setAttribute("data-shown", ""))
      })
    }
    sync()
  }

  const firstOf = (game) => chats.findIndex((c) => c.dataset.chatGame === game)
  tabs.forEach((tab, i) => {
    tab.addEventListener("click", () => {
      locked = tab.dataset.chatTab
      show(firstOf(locked))
    })
    tab.addEventListener("keydown", (e) => {
      const step = e.key === "ArrowRight" ? 1 : e.key === "ArrowLeft" ? -1 : 0
      if (!step) return
      e.preventDefault()
      const target = tabs[(i + step + tabs.length) % tabs.length]
      target.focus()
      target.click()
    })
  })
  dots.forEach((dot) => {
    dot.addEventListener("click", () => {
      locked = dot.dataset.chatGame
      show(Number(dot.dataset.chatDot))
    })
  })
  for (const [on, off] of [
    ["mouseenter", "mouseleave"],
    ["focusin", "focusout"],
  ]) {
    root.addEventListener(on, () => {
      hovered = true
      sync()
    })
    root.addEventListener(off, () => {
      hovered = false
      sync()
    })
  }
  if ("IntersectionObserver" in window) {
    new IntersectionObserver(
      ([entry]) => {
        visible = entry.isIntersecting
        sync()
      },
      {threshold: 0.4},
    ).observe(root)
  } else {
    visible = true
  }
  show(0)
}

// A strip's tabs mark themselves selected (the visual-only tabs on /design).
function tabStrips() {
  document.querySelectorAll("[data-tabs]").forEach((strip) => {
    const tabs = Array.from(strip.querySelectorAll("[role=tab]"))
    const select = (tab) => {
      tabs.forEach((t) => t.setAttribute("aria-selected", String(t === tab)))
    }
    tabs.forEach((tab, i) => {
      tab.addEventListener("click", () => select(tab))
      tab.addEventListener("keydown", (e) => {
        const step = e.key === "ArrowRight" ? 1 : e.key === "ArrowLeft" ? -1 : 0
        if (!step) return
        e.preventDefault()
        const next = tabs[(i + step + tabs.length) % tabs.length]
        next.focus()
        select(next)
      })
    })
  })
}

headerTheme()
chatDemo()
scrollSpy()
toggles()
copyButtons()
tabStrips()
