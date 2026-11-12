// The page's motion, after Mercury, and the two live demos of the app's own motion.
// Without this script the header is simply always frosted, nothing animates, and the demos sit still.
(function () {
  if (!("IntersectionObserver" in window)) return;
  var root = document.documentElement;
  var still = matchMedia("(prefers-reduced-motion: reduce)").matches;
  var PARTS = ["reading", "reflection", "prayer"];

  // The header: see-through while the top of the page is on screen, frosted glass once it scrolls away.
  root.classList.add("at-top");
  if (!still) root.classList.add("js-motion");

  document.addEventListener("DOMContentLoaded", function () {
    var marker = document.createElement("div");
    marker.setAttribute("aria-hidden", "true");
    marker.style.cssText = "position:absolute;top:0;left:0;width:1px;height:24px;pointer-events:none";
    document.body.prepend(marker);
    new IntersectionObserver(function (entries) {
      root.classList.toggle("at-top", entries[0].isIntersecting);
    }).observe(marker);

    document.querySelectorAll('[data-demo="today"]').forEach(todayDemo);
    if (still) return;

    // Sections: [data-reveal] elements get .is-in the first time they reach the screen; styles.css animates them in.
    var seen = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        entry.target.classList.add("is-in");
        seen.unobserve(entry.target);
      });
    }, { rootMargin: "0px 0px -10% 0px" });
    document.querySelectorAll("[data-reveal]").forEach(function (el) { seen.observe(el); });

    document.querySelectorAll(".reader-show").forEach(readerStory);
  });

  // Today: tick the three parts. Each tick hops its icon, ripples and fills its arc of today's ring; the last one
  // fills the ring green and lets the light settle on the card (moment A). It plays itself once when first seen.
  function todayDemo(demo) {
    var ring = demo.querySelector(".wk-today");
    var replay = demo.parentNode.querySelector(".replay");
    var timers = [];

    function set(part, on) {
      demo.querySelector('.tick[data-part="' + part + '"]').setAttribute("aria-pressed", String(on));
      demo.querySelector(".part-" + part).classList.toggle("is-ticked", on);
      ring.classList.toggle("on-" + part, on);
      var done = PARTS.every(function (p) { return ring.classList.contains("on-" + p); });
      ring.classList.toggle("is-done", done);
      demo.classList.toggle("is-done", done);
    }
    function stop() { timers.forEach(clearTimeout); timers = []; }
    function play() {
      stop();
      PARTS.forEach(function (p) { set(p, false); });
      PARTS.forEach(function (p, i) { timers.push(setTimeout(function () { set(p, true); }, 700 + i * 950)); });
    }

    demo.addEventListener("click", function (event) {
      var tick = event.target.closest(".tick");
      if (!tick) return;
      stop();
      set(tick.dataset.part, tick.getAttribute("aria-pressed") !== "true");
    });
    if (replay) replay.addEventListener("click", play);
    if (still) return;
    var once = new IntersectionObserver(function (entries) {
      if (!entries[0].isIntersecting) return;
      once.disconnect();
      play();
    }, { threshold: 0.6 });
    once.observe(demo);
  }

  // The reader: the page's scroll drives the phone. Its day scrolls by, the part in view widens in the tick bar,
  // each part ticks once you've read past it, and the finished day swaps the bar for the way back to Today.
  function readerStory(section) {
    var track = section.querySelector(".reader-track");
    var screen = section.querySelector(".reader-screen");
    var content = section.querySelector(".reader-content");
    var dock = section.querySelector(".dock");
    var blocks = PARTS.map(function (p) { return section.querySelector(".rd[data-part=\"" + p + "\"]"); });
    var chips = PARTS.map(function (p) { return section.querySelector(".chip-" + p); });
    var queued = false;

    function update() {
      queued = false;
      var box = track.getBoundingClientRect();
      var span = box.height - innerHeight;
      var progress = span > 0 ? Math.min(1, Math.max(0, -box.top / span)) : 0;
      var max = Math.max(0, content.scrollHeight - screen.clientHeight);
      var scrolled = Math.min(1, progress / 0.8);
      var offset = scrolled * max;
      content.style.transform = "translateY(" + -offset + "px)";
      // The part in view is the last one whose top has passed a reading line, which moves from a quarter of the
      // way down the screen to three quarters as the day scrolls by, so the first and the last part each get a turn.
      var line = offset + screen.clientHeight * (0.25 + 0.5 * scrolled);
      var active = 0;
      blocks.forEach(function (block, i) { if (block.offsetTop <= line) active = i; });
      var finished = progress > 0.9;
      chips.forEach(function (chip, i) { chip.classList.toggle("is-ticked", i < active || progress > 0.84); });
      dock.dataset.active = PARTS[active];
      section.dataset.active = PARTS[active];
      dock.classList.toggle("is-done", finished);
    }
    function queue() {
      if (queued) return;
      queued = true;
      requestAnimationFrame(update);
    }
    addEventListener("scroll", queue, { passive: true });
    addEventListener("resize", queue);
    update();
  }
})();
