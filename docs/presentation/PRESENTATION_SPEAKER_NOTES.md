# STORA Presentation: Slide-by-Slide Speaker Notes & Technical Glossary
**Deck:** Group 4 Topics 13–16: *Draw it, then prove it*  
**Application:** STORA (Smart POS & Micro-Commerce Platform)  
**Target Audience:** SIA Evaluators, Technical Panel, and Defense Committee

---

## 📖 Master Glossary: Technical Terms, Full Words & Their Purpose

| Term | Full Words / Expansion | Concrete Purpose in STORA |
| :--- | :--- | :--- |
| **UML** | **Unified Modeling Language** | A standardized visual modeling language used to create visual blueprints of system use cases, sequences, and class structures so developers and evaluators share the same mental model without ambiguity. |
| **C4 Model** | **Context, Containers, Components, Code** | A 4-level architectural zoom framework (created by Simon Brown) that organizes software diagrams like Google Maps, allowing high-level stakeholders to see Context (Level 1) and engineers to see Containers (Level 2). |
| **ADR** | **Architecture Decision Record** | A concise, 1-page immutable document capturing a major technical choice (e.g. PostgreSQL vs NoSQL), its problem context, and trade-offs so the team's rationale is preserved forever in version control. |
| **UAT** | **User Acceptance Testing** | The final pre-release testing phase where real end-users (5 real sari-sari merchants and 5 neighborhood shoppers) perform real tasks to verify that the app is genuinely usable in everyday life. |
| **RA 10173** | **Republic Act No. 10173 (Data Privacy Act of 2012)** | The Philippine data privacy law governing data collection, transparency, purpose limitation, and user consent, ensuring STORA participants' rights are respected during usability testing and account usage. |
| **a11y** | **Accessibility** (*"a"* + 11 letters + *"y"*) | Designing software so everyone—including elderly sari-sari owners, people with low vision, motor difficulties, color blindness, or those operating in direct noon tropical glare—can use the app effortlessly. |
| **WCAG** | **Web Content Accessibility Guidelines** | The international benchmark (W3C) establishing testable accessibility standards (e.g. 4.5:1 minimum text contrast, 44×44dp minimum touch target dimensions). |
| **ERD** | **Entity-Relationship Diagram** | A structural visual diagram modeling database tables (entities), columns, and relational foreign keys, ensuring data integrity before writing code. |
| **ACID** | **Atomicity, Consistency, Isolation, Durability** | The four essential database transaction guarantees in PostgreSQL that prevent financial data corruption in STORA's community debt (*utang*) ledger. |
| **POS** | **Point of Sale** | The retail checkout terminal interface where store owners scan items via camera, calculate change (*sukli*), record payments, and deduct inventory. |
| **API / REST** | **Representational State Transfer Application Programming Interface** | A standardized, stateless HTTP communication protocol allowing Flutter mobile apps to query and send data to the Django server using JSON payloads. |
| **JWT** | **JSON Web Token** | A cryptographically signed token enabling stateless user authentication between the mobile device and backend server without database lookups on every request. |
| **FCM** | **Firebase Cloud Messaging** | Google's cloud push notification service that delivers real-time order alerts and stock status updates to customer and owner devices. |
| **SIA** | **Systems Integration and Architecture** | The overarching software engineering discipline focusing on how multiple software components, databases, cloud infrastructure, and human workflows integrate into a coherent, defensible whole. |

---

## 📌 Quick Summary of Group 4's Mission
Groups 1 to 3 wrote the code and set up the databases.  
**Group 4’s job is to:**
1. **Draw the system** so anyone can understand it (C4 & UML).
2. **Defend our technical choices** in writing (ADRs).
3. **Prove real people can use it** with real sari-sari store owners and shoppers under Philippine privacy law (UAT & RA 10173).
4. **Make it accessible** for everyone, including users under direct sunlight, with low vision, or using screen readers (WCAG Accessibility).

---

## Slide 1: Title Slide — "Draw it, then prove it"
* **What it means:**  
  Writing code that compiles is only half the battle. If you cannot explain your architecture, justify your tech stack, or prove real people can operate your app, your project is not ready for production.
* **Simple Explanation:**  
  "Welcome. Today, we are presenting the architecture, technical decisions, and real-world validation of STORA. We aren't just showing you that our code runs—we are showing you how it is built, why we made every major decision, and the evidence that real neighborhood store owners and shoppers can use it without getting stuck."
* **Presenter Tip:** Keep it confident and clear. Emphasize the four pillars: Diagrams, ADRs, User Testing, and Accessibility.

---

## Slide 2: Four Topics: Make the System Legible, Then Validated
* **What it means:**  
  Group 4 covers two architecture topics (C4 Diagrams & ADRs), one testing phase (UAT), and one production requirement (Accessibility).
* **Simple Explanation:**  
  "In a software company, different teams have distinct roles. Groups 1, 2, and 3 built the backend and mobile apps. Group 4's job is quality and proof:
  1. **Topic 13 (C4/UML):** We draw the blueprints.
  2. **Topic 14 (ADRs):** We document why we chose our tech stack so no one has to guess.
  3. **Topic 15 (UAT):** Real sari-sari store owners test the app under signed privacy consent.
  4. **Topic 16 (Accessibility):** We make sure anyone can use it—even outside under the bright sun or with vision difficulties.  
  Once we sign off on this, Group 5 can safely deploy the app to production."

---

## Slide 3: Why This Matters — "A system nobody can explain is one nobody can trust"
* **What it means:**  
  A working app is just a rumor if you cannot explain it to a panel or an investor.
* **Simple Explanation:**  
  - **Show it:** A clear picture explains the architecture in 30 seconds. A block of text confuses people.
  - **Justify it:** When the panel asks: *"Why did you use Django instead of Node? Why PostgreSQL instead of MongoDB?"*—we don’t make up an answer on the spot. We pull up an ADR written months ago.
  - **Prove it:** Saying *"our app is easy to use"* is just our opinion. Showing 5 sari-sari store owners successfully completing a sale in 54 seconds is **proof**.

---

## Slide 4: Topic 13 — C4 & UML Diagrams (Section Cover)
* **What it means:**  
  Introducing software diagrams. The key rule here is "zoom level."
* **Simple Explanation:**  
  "You wouldn't show a city road map to someone trying to assemble a motor. Similarly, in software, you need different diagram zoom levels depending on who you are talking to."

---

## Slide 5: Four Zoom Levels — Show Only What the Audience Needs
* **What it means:**  
  The C4 model is like Google Maps for software architecture:
  1. **Level 1 (System Context - World View):** STORA is one box in the middle. Around it are the people and services that talk to it: Store Owners, Shoppers, GCash QR, and Firebase.
  2. **Level 2 (Container - City View):** The big working pieces: the Owner Flutter app, Customer Flutter app, Django REST API backend, and PostgreSQL database on Render.
  3. **Level 3 (Component - Street View):** Looking inside the backend container at the auth system, checkout engine, and push notification dispatcher.
  4. **Level 4 (Code - House Interior):** Exact classes and code functions (usually auto-generated).
* **Presenter Tip:** Tell the panel: *"For our defense, Level 1 and Level 2 are the most important because they show who uses STORA and what moving parts keep it alive."*

---

## Slide 6: Three UML Diagrams That Earn Their Keep
* **What it means:**  
  Don't draw dozens of useless UML diagrams. Only draw the ones that answer real questions:
  1. **Use-Case Diagram:** Answers *"Who can do what?"* (Store owners add stock and log utang; shoppers browse nearby stores and order).
  2. **Sequence Diagram:** Answers *"What talks to what, and in what order?"* (e.g., Owner scans barcode ➔ local SQLite saves it ➔ Django updates database ➔ Firebase sends notification).
  3. **Class / ERD:** Answers *"How is the database structured?"* (Shows Users, Stores, Products, Orders, and the Utang Ledger).
* **Golden Rule:** *"A diagram that doesn't match the real code is worse than no diagram at all. We make sure our diagrams match our actual database schema."*

---

## Slide 7: Topic 14 — Architecture Decision Records (ADRs) (Section Cover)
* **What it means:**  
  Transitioning to architectural reasoning. Diagrams show **what** we built; ADRs explain **why** we built it that way.

---

## Slide 8: One Short Page Per Decision — Four Headings, That Is All
* **What it means:**  
  An ADR is a short, 1-page document capturing a technical decision so teams don't waste time re-arguing it later.
* **The 4 Headings:**
  1. **Status:** Is it Proposed, Accepted, or Superseded?
  2. **Context:** What was the problem and constraint? (e.g., Slow Philippine mobile internet).
  3. **Decision:** Exactly what we chose (e.g., Django REST Framework with standard HTTP caching).
  4. **Consequences:** What got easier, and what trade-offs did we accept?
* **Example:** ADR-0001 explains why STORA chose Django REST over GraphQL—it allows standard HTTP caching headers and faster development for intermittent rural 3G/4G connections.

---

## Slide 9: Record the Decisions That Were Hard to Make or Reverse
* **What it means:**  
  You don't write an ADR for every small line of code. You only write one for decisions that would take weeks to change if you were wrong.
* **In STORA, our 6 ADRs cover:**
  1. REST vs GraphQL (caching & simplicity).
  2. PostgreSQL vs NoSQL (ACID reliability for debt/money ledgers).
  3. Dual Flutter Apps (lightweight separate apps for Owners and Customers).
  4. Drift/SQLite Offline Cache (owners can ring up sales even during power or internet outages).
  5. RA 10173 Data Privacy (role isolation and permanent account deletion).
  6. Hybrid JWT + Firebase Auth (secure token authentication).
* **Where they live:** All 6 live in `docs/adr/` in our repository, tracked by Git.

---

## Slide 10: Topic 15 — UAT & Consent (Section Cover)
* **What it means:**  
  Moving from code design to human testing. Unit tests prove the logic works; User Acceptance Testing (UAT) proves normal humans can actually use it.

---

## Slide 11: Silent Observation Protocol — Give Real Users a Task, Then Watch
* **What it means:**  
  How to conduct honest usability testing without cheating:
  - **Recruit real target users:** 5 sari-sari store owners and 5 neighborhood shoppers (not the programmers who built it).
  - **Give a clear task, not a guided tour:** Say *"Scan 2 items and ring up cash payment"*, then step back.
  - **Silent Observation:** Do not coach them or say *"click there"*. If they struggle or hesitate, that struggle is the exact bug we need to fix in the UI.
  - **Pre-agreed Acceptance Criteria:** Before testing, we set the bar: *"4 out of 5 merchants must complete checkout in under 90 seconds."*  
    **Our Result:** All 5 passed, averaging **54 seconds**.

---

## Slide 12: Testing with People is a Privilege — Ask First (RA 10173)
* **What it means:**  
  Republic Act No. 10173 is the **Philippine Data Privacy Act of 2012**. You cannot collect people's names, photos, or test data without formal written consent.
* **The 4 Pillars in our Consent Form:**
  1. **Task Description:** Tell them what they will do and how long it takes (10–15 mins).
  2. **Data Collected:** Only UI friction and completion times—zero credit cards or passwords.
  3. **Voluntary:** They can stop at any second without penalty.
  4. **Confidentiality:** All responses are de-identified and can be deleted on request.
* **Deliverable:** We have our formal 1-page consent form ready in `docs/uat/INFORMED_CONSENT_FORM_RA10173.md`.

---

## Slide 13: Topic 16 — Accessibility (Section Cover)
* **What it means:**  
  "Works on my phone" is not acceptable. Sari-sari store owners often work outdoors in glaring tropical heat, might be elderly, or have low vision.

---

## Slide 14: Five Core Habits Cover Most Users
* **What it means:**  
  Meeting accessibility isn't impossible; 5 core fixes solve 90% of user barriers:
  1. **Contrast (4.5:1 ratio or higher):** STORA achieved a **15.8:1** contrast ratio so owners can read prices outside in blinding noon sunlight.
  2. **Big Touch Targets (44dp minimum):** Our menu buttons are **54dp** so store owners with shaky hands or people walking can tap easily without missing.
  3. **Screen Reader Labels:** Every icon button has an English/Tagalog descriptive label for Android TalkBack.
  4. **Don't Rely on Color Alone:** Error fields say *"Required"*, not just a red border (for color-blind users).
  5. **Scalable Text:** If an older store owner zooms their phone font to 150%, the text wraps cleanly instead of breaking the layout.

---

## Slide 15: You Can Check the Basics in 15 Minutes
* **What it means:**  
  How we proved accessibility:
  - **TalkBack test:** We turned on Android TalkBack, turned off the screen, and navigated using only audio cues.
  - **Font scaling test:** Maxed out system font size to 200% to ensure zero text overflows.
  - **Free Contrast Checker:** Verified high contrast across all main screens.
  - **Honest Engineering Gap:** We tell the panel the truth: *"We perfected screen contrast and navigation labels; adding audio beeps during camera barcode scanning is our next planned update."* Panels respect honesty over fake perfection.

---

## Slide 16: Group 4 in Context — The Last Checkpoint Before the World Sees It
* **What it means:**  
  Understanding the software team pipeline:
  - **Groups 1–3:** Built the foundation (database, API, and UI widgets).
  - **Group 4:** The bridge—we make the architecture legible, write the ADRs, test with real humans, and enforce accessibility.
  - **Group 5:** The deployment gate—they cannot release the app until Group 4 signs off that UAT and accessibility have passed.

---

## Slide 17: The Demo / Defense Playbook — Four Moves
* **What it means:**  
  When defending before the panel, execute these four quick moves:
  1. **Move 1 (Diagram):** Spend 30 seconds explaining the Container Diagram (Owner App ➔ Backend ➔ PostgreSQL).
  2. **Move 2 (ADR):** Read one ADR aloud (e.g., ADR-0002: PostgreSQL guarantees zero lost utang records thanks to ACID transactions).
  3. **Move 3 (UAT):** Show our 54-second average checkout time against our 90-second target, plus the signed consent form.
  4. **Move 4 (Accessibility):** Show before/after touch targets and contrast, and name our next milestone.

---

## Slide 18: What Good Looks Like — The 20-Point Checklist
* **What it means:**  
  A scorecard showing that every requirement is 100% satisfied:
  - **Diagrams:** Context, Container, correct zoom, matching ERD, up-to-date.
  - **ADRs:** 6 real ADRs, 4 headings each, stored in `docs/adr/`, versioned in Git.
  - **UAT:** Real sari-sari owners, clear pass criteria, silent observation, written findings, signed RA 10173 consent.
  - **Accessibility:** 15.8:1 contrast, screen reader labels, 54dp targets, not color alone, TalkBack verified.

---

## Slide 19: Wrap-Up & Hand-off to Group 5
* **What it means:**  
  The conclusion:
  - **What we produced:** Blueprints, 6 ADRs, UAT results with signed consent, and production accessibility fixes.
  - **What’s next:** Group 5 takes over to run load testing, monitor server security, and push the final button to deploy STORA to Google Play.
