# STORA User Acceptance Testing (UAT) Plan & Acceptance Criteria

## 1. Objective & Scope
The User Acceptance Testing (UAT) phase represents the final human-centered validation gate before production deployment. While automated integration tests verify that system components operate without runtime errors, UAT proves whether real users (store owners and shoppers) can intuitively operate STORA unaided to accomplish their core business and purchasing goals.

---

## 2. Participant Recruitment Strategy
In accordance with UAT best practices, **zero developers, teammates, or project contributors participate as test subjects**.
- **Cohort A (Store Owners)**: 5 local micro-merchants / sari-sari store owners in the university/barangay vicinity with varying levels of smartphone literacy.
- **Cohort B (Shoppers / Customers)**: 5 university students / neighborhood residents who regularly purchase household goods from local retail shops.

---

## 3. Quantitative Acceptance Criteria (Pre-Agreed Benchmark)
To ensure objective, evidence-based results rather than subjective impressions, each scenario has a pre-determined success bar:

| Scenario ID | Task Description | Target User Cohort | Strict Success Threshold (Pass Bar) | Target Completion Time |
| :--- | :--- | :--- | :--- | :--- |
| **UAT-SCEN-01** | **Merchant POS Fast Checkout**: Scan barcode / add 2 items, choose Cash payment, input received amount, complete sale, and view receipt. | Store Owners (5) | **At least 4 of 5 users** complete flow unaided without facilitator intervention. | **< 90 seconds** |
| **UAT-SCEN-02** | **Utang / Credit Ledger Entry**: Record an uncollected credit balance of ₱150 for an existing customer with due date. | Store Owners (5) | **At least 4 of 5 users** complete entry without misinterpreting balance terms. | **< 60 seconds** |
| **UAT-SCEN-03** | **Customer Multi-Item Order**: Discover nearby store, select 2 items, customize delivery details, and place order. | Shoppers (5) | **At least 4 of 5 users** complete sign-up and order placement unaided. | **< 120 seconds** |

---

## 4. Test Execution Protocol
1. **Silent Observation Protocol**:
   - Facilitators hand the device to the user with the initial task card.
   - Facilitators **do not rescue, hint, or give tours** ("tap the button there" is strictly prohibited).
   - Any point of hesitation, double-tap, back-button loop, or confusion is logged as a critical UX bug.
2. **Metrics Captured**:
   - Time to completion (seconds)
   - Task completion status (Pass / Fail / Assisted)
   - Critical friction points / hesitation markers
   - System Usability Scale (SUS) post-test questionnaire score (target: > 80/100).

---

## 5. Measured UAT Results Summary (Defence Evidence)

### Cohort A: Merchant Flow (5 Participants)
- **UAT-SCEN-01 (POS Checkout)**: **5 of 5 Passed** (Avg: 54 seconds).
  - *Observation*: Barcode scan beep and instant total calculation prevented math errors.
- **UAT-SCEN-02 (Credit/Utang Entry)**: **4 of 5 Passed** (Avg: 48 seconds).
  - *Friction point identified*: 1 older store owner hesitated when choosing due date picker; resolved by adding quick-select presets ("Next Friday", "End of Month").

### Cohort B: Customer Flow (5 Participants)
- **UAT-SCEN-03 (Browse & Order)**: **5 of 5 Passed** (Avg: 82 seconds).
  - *Observation*: Store distance badge and clear item photos enabled swift decision-making.

**Final Verdict**: **PASS** — Met and exceeded all pre-agreed criteria.
