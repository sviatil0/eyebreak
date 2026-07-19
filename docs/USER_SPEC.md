# User Input — Raw Product Spec (2026-07-19)

Goal: open-source analog of https://lookaway.com/ for macOS. Purpose: help reduce digital eye strain. User will add further eye-health directives over time.

---

## Health objective

The app should target the most supported, low-risk interventions for screen-related eye discomfort: regular look-away breaks, reduced continuous near focus, better blinking behavior, and dry-eye support.

It should not claim to improve eyesight, reverse myopia, or "train vision" in a medical sense, because the better-supported benefits are symptom reduction, not prescription change.

## Core behaviors

The primary feature should be a 20-20-20 reminder: every 20 minutes, prompt the user to look at something about 20 feet away for at least 20 seconds. The app should also encourage a few relaxed blinks during each break, because screen use is associated with dry eye and blink reduction.

Secondary health behaviors can be optional:

- Blink reminder during long coding sessions, because digital screen use contributes to dry-eye symptoms.
- Daily warm-compress reminder for users with dryness, since Mayo Clinic recommends warm compresses and eyelid hygiene for dry-eye relief.
- Artificial-tears reminder for people who already use lubricating drops, with preservative-free guidance for frequent use.
- Environment reminders such as "reduce glare" or "move fan/AC away from face," because glare and dry moving air worsen eyestrain and dryness.

## Product requirements

The app should be minimal and menu-bar first, because adherence matters more than feature count for behavior-change tools. It should support:

- Recurring 20-20-20 reminders with snooze, skip, and "done."
- Quiet mode during presentations, calls, or full-screen coding.
- Custom intervals, while keeping 20-20-20 as the default evidence-based preset.
- Optional webcam-free mode by default, since the health benefit comes from reminders themselves, not camera tracking.
- Daily streaks and adherence stats framed around comfort habits, not medical outcomes, because symptom relief was shown while reminders were used.

Health copy inside the app should stay conservative:

- "May reduce eye strain and dry-eye symptoms."
- "Supports healthier screen habits."
- Avoid: "improves vision," "strengthens eye muscles," "fixes eyesight," or "clinically cures dry eye."

## Safety and escalation

The app should include a short "when to get checked" panel, because persistent symptoms can reflect dry-eye disease, allergies, or uncorrected vision problems. It should tell users to seek care for pain, light sensitivity, discharge, sudden vision changes, or ongoing symptoms despite breaks and lubrication.

For itch specifically, the app can mention that allergy-type symptoms are often managed with trigger avoidance and antihistamine drops such as ketotifen, but it should present this as educational information and not personalized medical advice.

## Example spec text

App purpose: Help laptop users reduce digital eye strain, dryness, and screen-related visual fatigue by building consistent, evidence-based break habits.

Primary outcome: Improve comfort during prolonged screen work by increasing look-away breaks and reducing uninterrupted near-focus time.

Secondary outcomes: Support blinking, reduce dryness triggers, and remind users about proven self-care steps like warm compresses and lubricating drops when relevant.

Non-goals: The app does not diagnose eye disease, replace an eye exam, or claim to improve refractive error or permanently improve vision.
