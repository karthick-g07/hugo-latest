# Quality Sweets Billing App
## Complete Product Idea, Requirements, Features, and Mobile UX Specification

**Document purpose:** This is the master product brief for designing and building the Quality Sweets billing app. It consolidates the original requirements and adds practical features for a real sweet shop counter. Use it as the source of truth for UI design, prototyping, and implementation.

---

## 1. Product Overview

**App name:** Quality Sweets Billing App  
**Business:** Quality Sweets, a sweets and snacks shop  
**Primary users:** Shop owner/admin and counter staff  
**Primary goal:** Create customer bills quickly, accurately, and conveniently from a phone or tablet.

The app should support three ways to add an item to a bill:

1. **Weight-based billing:** Enter grams or kilograms, use a rate per kilogram, and calculate the price automatically.
2. **Amount-based / quick billing:** Enter the amount the customer wants to pay for an item, and calculate the corresponding quantity when a rate per kilogram is available. If quantity is unknown or not needed, allow a bill line with an amount only.
3. **Fixed-price / unit billing:** Add an item sold per piece, packet, box, or other unit with a fixed price and quantity.

The app should be mobile-first, touch-friendly, fast, and usable at a busy billing counter. It should store data locally on the device without requiring a backend or cloud database.

## 2. Design Direction

- **Visual style:** Premium, warm, modern, clean, and practical.
- **Primary color:** Deep maroon/burgundy.
- **Secondary color:** Warm cream/ivory.
- **Accent:** Saffron or muted gold.
- **Text:** Dark charcoal with high contrast.
- **Cards:** Rounded corners, subtle borders, restrained shadows.
- **Imagery:** Appetizing Indian sweets and savory snacks, where images help identify products.
- **Currency:** Indian rupees (₹).
- **Language:** Start with English; keep the design ready for Tamil labels later if required.
- **Layout:** Mobile-first. Support small phones, large phones, and tablets. On a phone, use clear screens and bottom navigation; on a tablet, a persistent current-bill panel can speed up checkout.
- **Accessibility:** Large tap targets, readable prices, visible field labels, clear validation messages, and keyboard-friendly dialogs.

Avoid making the app look like an online shopping storefront. It is a point-of-sale billing tool.

## 3. Main Navigation

Recommended mobile bottom navigation:

1. **Home**: Product categories and quick-add items.
2. **Bill**: Current bill and totals.
3. **Saved**: Saved bills and invoice sharing.
4. **Admin**: Products, categories, rates, and settings.

Keep a visible **New Bill** action on the Bill screen and/or as a floating action button, positioned so it does not cover important content.

Optional shortcut: **Quick Add** from the home screen or current bill for items not already in the catalog.

## 4. Home Screen and Main Categories

The home screen should display the Quality Sweets logo/name, search, current bill indicator, and category cards.

### Required main categories

1. **Normal Sweets**
2. **Special Sweets**
3. **Karam & Savories**
4. **Top Rated Specials**
5. **Other Items** (important new category)

The **Other Items** category is for products that do not fit the normal categories, including other snacks, seasonal products, miscellaneous shop items, or items the owner adds later.

Examples of possible Other Items:
- Chips or packaged snacks
- Biscuits
- Chocolates
- Drinks
- Water bottles
- Gift boxes
- Party/seasonal packs
- Miscellaneous items

These are examples only. The owner should be able to create any product or category.

### Home screen features

- Search across all products.
- Category cards with image, name, and product count.
- Top-rated/popular products section.
- Recently used products or quick-add shortcuts (optional but useful).
- A clear indicator showing the current bill's item count and total.
- Quick Add / Custom Item action for a product not in the catalog.
- Admin can choose which products appear in Top Rated Specials. Do not automatically infer ratings from price.
- Categories and products should be managed by the admin, not hard-coded.

## 5. Product Categories and Product Listing

When the user taps a category, show its products in a clean grid or list.

Each product card should display:
- Product image (optional)
- Product name
- Default rate and billing unit, such as ₹280/kg, ₹20/piece, or ₹50/packet
- Optional Popular label
- Add/select action

Features:
- Search within the category.
- Sort by name or price.
- Show active products only by default.
- Product selection opens the appropriate billing dialog based on its billing type.
- The user can return to the category without losing the current bill.
- The Other Items category must work just like all other categories.

## 6. Product Types and Billing Modes

Every product should have a configurable **billing mode**.

### A. Weight-based product

Examples: Mysore Pak, Kaju Katli, mixture, murukku sold by weight.

Product settings:
- Default rate per kilogram
- Default weight entry unit (grams or kilograms, optional preference)
- Allow temporary rate override during billing
- Optional image and category

Calculation:
- `weightKg = weightGrams / 1000`
- `lineAmount = weightKg × appliedRatePerKg`

Examples:
- Rate ₹280/kg, weight 8,800 g = 8.8 kg, amount ₹2,464.
- Rate ₹280/kg, weight 250 g = 0.25 kg, amount ₹70.
- Rate ₹900/kg, weight 500 g = 0.5 kg, amount ₹450.

### B. Amount-based / quick billing

This is required for cases where the cashier knows the amount the customer wants but does not want to enter the weight first.

When selecting a weight-based product, provide two modes/tabs:

- **Enter Weight**
- **Enter Amount**

In **Enter Amount** mode:
- Cashier enters a target amount, e.g. ₹100.
- If the product has a valid rate per kg, calculate the equivalent weight:
  - `weightKg = amount / ratePerKg`
  - `weightGrams = weightKg × 1000`
- Show the calculated weight as an estimate, with sensible precision.
- Allow the cashier to add the item at the entered amount.
- If the actual shop scale weight is known afterward, the cashier can switch to weight mode and correct it.
- Do not silently change the entered amount due to display rounding of the calculated weight. The source of truth should be explicit.

Example:
- Kaju Katli rate: ₹900/kg.
- Customer requests ₹100 worth.
- Calculated weight: about 111.111 g.
- Bill amount: ₹100.00.
- Show quantity approximately 111.11 g (derived from amount), unless the cashier edits the quantity or amount.

**Important distinction:** Amount-based billing is not the same as entering grams. If the user enters an amount, preserve that amount as the line amount. The calculated quantity may be approximate. If the product's rate is missing, allow an amount-only line and mark the quantity as not specified.

### C. Amount-only / custom bill line

Sometimes the cashier needs to enter an amount directly without a meaningful weight or catalog rate.

Examples:
- A miscellaneous snack for ₹35
- A one-off item not yet in the product catalog
- A manually agreed amount
- A charge or adjustment, if the shop chooses to support it

Provide a **Custom Item / Amount Only** action:
- Item name/description
- Amount
- Optional quantity or note
- Add to Bill

If the cashier does not know the item name, allow a generic name such as "Other Item", but encourage entering a description for clear invoices.

### D. Fixed-price unit product

Examples: individual sweets, snack packets, gift boxes, bottled drinks.

Product settings:
- Unit type: piece, packet, box, bottle, plate, or custom unit
- Default price per unit

Billing:
- Enter number of units.
- `lineAmount = unitCount × unitPrice`
- Allow a temporary per-unit price override if the shop owner wants this enabled.

Example:
- Snack packet: ₹20 each.
- Quantity: 3 packets.
- Total: ₹60.

### E. Optional preset weight buttons

For weight-based products, show quick buttons such as:
- 100 g
- 250 g
- 500 g
- 1 kg
- 2 kg

These should populate the input, not bypass the normal calculation. The cashier can still enter any custom value, including 8,800 g or 8.8 kg.

## 7. Product Weight and Rate Dialog

When a weight-based product is selected, open a mobile bottom sheet or full-screen dialog.

Display:
- Product name and optional image
- Default rate/kg from Admin
- Applied rate/kg input, initially filled with the default
- Toggle: Enter Weight / Enter Amount
- Weight input and unit selector (g/kg), or amount input
- Equivalent weight in both g and kg
- Calculated amount
- Add to Bill and Cancel buttons

### Weight input requirements

- Support grams and kilograms.
- 8,800 g must display as 8.8 kg.
- 8.8 kg must display as 8,800 g.
- Accept decimal kilograms, e.g. 0.25 kg, 1.5 kg, 8.8 kg.
- Unit switching must not accidentally convert the value twice.
- Keep internal numeric values separate from formatted display strings.

### Temporary price override

If Admin default rate is ₹280/kg, show ₹280 initially. The cashier may change it to ₹260/kg for this bill line.

- The override applies only to the current bill line.
- It must not modify the Admin default.
- Clearly show default and applied rates if they differ.
- If the same product is added again at a different rate, preserve separate line items or retain separate rate-specific entries. Do not merge items with different applied rates.

### Validation

- Weight must be greater than zero for weight mode.
- Amount must be greater than zero for amount mode.
- Rate must be a valid non-negative number; if a rate is zero or missing, do not divide by it to calculate weight.
- Show clear errors rather than silently correcting invalid entries.
- Prevent double-adds from rapid repeated taps.

## 8. Current Bill Screen

Show a live invoice-like list of the items added to the current bill.

Each line should include:
- Product/item name
- Billing mode
- Weight in g and kg, or unit count, or amount-only label
- Applied rate
- Line amount
- Edit action
- Remove action

Example:

| Item | Quantity | Rate | Amount |
|---|---:|---:|---:|
| Ghee Mysore Pak | 8.8 kg / 8,800 g | ₹280/kg | ₹2,464.00 |
| Kaju Katli | 500 g / 0.5 kg | ₹900/kg | ₹450.00 |
| Mixture | 1.25 kg / 1,250 g | ₹240/kg | ₹300.00 |
| Snack Packet | 3 packets | ₹20/packet | ₹60.00 |
| Other Item | Amount only | — | ₹35.00 |

Subtotal: ₹3,309.00

The values above are illustrative.

### Current bill actions

- Add more products
- Edit a line item
- Remove a line item
- Clear current bill (with confirmation)
- Save Bill
- New Bill
- Share/Preview (optional, if bill can be previewed before saving)

The grand total must be clearly visible. Update it after every item change.

### Optional useful features

- **Discount:** Optional bill-level discount, fixed amount or percentage, only if enabled by Admin. Show subtotal, discount, and final total separately.
- **Customer name/phone:** Optional, not mandatory for walk-in customers.
- **Notes:** Optional note for the invoice, e.g. "Gift packing".
- **Payment status/method:** Optional setting such as Cash, UPI, Card, or Unpaid. Do not require payment tracking if the shop only needs simple bills.
- **Remove/undo:** Offer a brief Undo action after removing an item to prevent mistakes.
- **No tax assumptions:** Do not automatically add GST or invent tax details. Tax fields and calculations must be explicitly configured by the shop owner if needed.

## 9. New Bill and Draft Protection

When New Bill is tapped while the current bill has items, show:

**Start a New Bill?**
- Save & Start New Bill
- Delete & Start New Bill
- Cancel

### Save & Start New Bill
- Ask for a bill name.
- Suggest a name such as `Bill - 24 Oct 2026 - 01`.
- Save the complete bill locally.
- Start a fresh draft.
- Preserve the previous bill exactly.

### Delete & Start New Bill
- Ask for confirmation.
- Delete only the current unsaved draft.
- Never delete other saved bills.

### Cancel
- Close the dialog and preserve the current draft.

If the current draft is empty, create a new draft without unnecessary confirmation.

The app should autosave the current draft locally as a safety measure, but autosaving a draft should not silently mark it as a completed saved invoice.

## 10. Saving Bills

When Save Bill is tapped:
- Ask for a bill name if it does not already have one.
- Use a sensible suggested name and unique local bill ID.
- Save all item snapshots, applied rates, quantities, amounts, subtotal, discount (if used), and grand total.
- Save date/time and any optional customer details.
- Confirm that the bill was saved.
- Keep a clear distinction between an unsaved draft and a saved bill.

Existing saved bills should not be overwritten accidentally. When editing a saved bill, offer Save Changes or Save as a Copy if that better fits the chosen workflow.

## 11. Saved Bills Screen

List saved bills with:
- Bill name
- Bill number/ID
- Date and time
- Number of line items
- Total
- View
- Edit/Resume
- Share
- Delete

Features:
- Search by bill name or ID.
- Sort by newest, oldest, or amount.
- Open invoice preview.
- Resume editing without losing data.
- Delete with confirmation.
- Empty state when there are no saved bills.

If the cashier switches to another bill while an unsaved draft exists, protect that draft with Save, Discard, or Cancel choices.

## 12. Invoice Preview and Sharing

The invoice should look professional and readable on a phone and when exported.

Include:
- Quality Sweets name/logo
- Shop address and phone if configured
- Bill ID/number
- Date and time
- Optional customer name/phone
- Item description
- Quantity and unit
- Applied rate
- Line amount
- Subtotal
- Discount, if enabled
- Configured tax details only if enabled
- Grand total
- Optional payment method/status
- Footer: "Thank you for shopping with Quality Sweets!"

Do not invent a GSTIN, tax registration number, address, or phone number.

### Sharing options

- Share as PDF
- Share as Image
- Share via WhatsApp
- Use device share sheet when supported
- Download/export fallback

### WhatsApp workflow

1. Choose a saved bill or preview the current bill.
2. Generate PDF or image.
3. Choose a contact only if the platform supports contact selection and the user grants permission.
4. Otherwise enter a phone number manually with country code.
5. Open WhatsApp using a supported sharing mechanism.
6. Let the user confirm the recipient and send.

A browser cannot be assumed to have unrestricted access to contacts or to attach files automatically. Use the native share sheet or platform-supported file-sharing mechanism where possible. If direct attachment is unavailable, provide an export/download fallback. Never claim a bill was sent unless the user actually completes sending it.

## 13. Admin Dashboard

Admin should be able to configure products, categories, rates, shop information, and data management.

### Dashboard overview
- Number of active products
- Number of categories
- Number of saved bills
- Frequently billed products based on available local bill data
- Shortcuts to manage products, categories, settings, and backup

Do not show invented sales figures.

### Product management
- Search products
- Add, edit, activate/deactivate, and delete products
- Set product name and category
- Set optional image
- Set billing mode: weight-based, amount-only/quick billing, or fixed-price unit
- Set default rate per kg for weight-based products
- Set unit type and default price per unit for fixed-price products
- Set whether temporary rate override is allowed
- Mark products as Popular/Top Rated
- Set active/inactive status

### Category management
- Add, rename, reorder, activate/deactivate, and delete categories
- Upload/change category image
- Show product count
- Handle category deletion safely: ask to move or reassign its products instead of silently deleting them
- Ensure **Other Items** exists by default but can be renamed or customized if desired

### Shop settings
- Shop name (default: Quality Sweets)
- Logo
- Address
- Phone number
- Optional tax information
- Invoice footer
- Currency (default INR)
- Invoice numbering preference
- Optional discounts/tax settings
- Optional payment method choices

## 14. Custom Item and Quick Add

Provide a **Quick Add / Custom Item** button on Home and Current Bill.

The dialog should allow the cashier to:
- Enter item name
- Choose category, defaulting to Other Items
- Choose billing mode:
  - Weight + rate/kg
  - Enter amount
  - Fixed price per unit
  - Amount only
- Enter a one-time price or quantity
- Add the item to the current bill

Offer two paths:

**Add once:** Add the item only to the current bill; do not save it to the catalog.

**Save as product:** Save it to the catalog for future use. The cashier/admin can enter a default rate and billing mode. If no default rate is known, allow a product to be saved as requiring a rate at billing time, if Admin enables this.

This solves the situation where the shop sells an unfamiliar snack or miscellaneous item that has not yet been configured.

## 15. Local Storage and Data Persistence

All core business data must remain on the device. Do not require Firebase, Supabase, a remote database, a backend server, or cloud synchronization.

For a browser-based app:
- Use IndexedDB for products, categories, saved bills, drafts, settings, and structured data.
- Use localStorage only for lightweight preferences where appropriate.
- Keep a stable local schema and unique IDs.
- Store a snapshot of product name, billing mode, quantity, applied rate, and amount on each bill line. Later product changes must not rewrite historical invoices.
- Restore the current draft after a refresh/reopen.
- Make core billing available offline after the app has loaded and its assets are available locally.
- If images are stored locally, resize/compress them sensibly to avoid filling storage.
- Provide JSON export/import backup.
- Confirm before clearing all local data.
- Warn that local-only data does not sync between devices and may be lost if browser/app data is cleared or the device is lost.

### Data backup
- Export all app data as a JSON backup.
- Import a JSON backup after validating its structure.
- Before importing, explain whether it will merge or replace existing data. Prefer a safe preview and explicit choice.
- Offer a backup reminder indicator or a "Last backup" date if backup metadata can be stored locally.
- Clear all data only after strong confirmation.

## 16. Data Model Guidance

Use structured records with unique IDs. Suggested entities:

### Product
- id
- name
- categoryId
- image reference (optional)
- billingMode: `weight`, `unit`, or `amountOnly`
- defaultRatePerKg (for weight mode)
- unitLabel and defaultUnitPrice (for unit mode)
- allowRateOverride
- isPopular
- isActive
- createdAt
- updatedAt

### Category
- id
- name
- image reference (optional)
- displayOrder
- isActive
- isSystemCategory (optional)

### Bill
- id
- displayNumber
- name
- status: `draft` or `saved`
- createdAt
- updatedAt
- customerName (optional)
- customerPhone (optional)
- notes (optional)
- lineItems
- subtotal
- discount (optional)
- configuredTax (optional)
- grandTotal
- paymentMethod/status (optional)

### Bill line item snapshot
- id
- productId (optional for one-off custom item)
- itemNameSnapshot
- billingMode
- quantityGrams / quantityKg (weight mode, as appropriate)
- unitCount and unitLabel (unit mode)
- enteredAmount (amount-based mode, if used)
- defaultRateSnapshot (optional)
- appliedRate
- lineAmount
- note (optional)

### App settings
- shop details
- invoice preferences
- discount/tax feature flags and configuration
- enabled payment methods
- last backup timestamp (optional)

The exact schema can be adapted by the developer, but historical invoice snapshots and unique IDs are essential.

## 17. Calculation Rules and Edge Cases

- 1 kg = 1,000 g.
- Weight-mode line amount = weight in kg × applied rate/kg.
- Amount-based line amount = the amount entered by the cashier; calculated weight is a derived estimate.
- Unit-mode line amount = unit count × applied price/unit.
- Amount-only line amount = amount entered by the cashier.
- Do not calculate estimated weight if the rate is missing or zero.
- Use consistent decimal-safe arithmetic and currency rounding.
- Show amounts to two decimal places when necessary.
- Do not round weight to whole kilograms.
- Validate that numeric values are finite and within reasonable limits.
- Keep numeric values separate from formatted strings.
- Do not silently convert units twice.
- Recalculate subtotal and grand total after each edit, removal, discount, or configured tax change.
- If amount-based weight is displayed with rounded decimals, preserve the entered amount as the source of truth unless the cashier explicitly switches to weight-based pricing.
- When rate overrides differ, do not merge those lines in a way that loses pricing history.
- Avoid accidentally adding an item twice from repeated taps.
- Avoid accidentally losing a draft when navigating, refreshing, or starting a new bill.

## 18. Optional Features Worth Considering

These are additions that may improve daily use. Keep them optional so the core app remains simple.

### High-value additions
1. **Recent products:** Quickly re-add frequently used items.
2. **Preset weights:** 100 g, 250 g, 500 g, 1 kg, and 2 kg buttons.
3. **Quick amount buttons:** For example ₹50, ₹100, ₹200, ₹500 on the amount-based entry screen; allow custom values.
4. **Undo remove:** Restore a recently removed line item.
5. **Customer details:** Optional customer name and phone, not required for walk-in sales.
6. **Bill notes:** Gift packing, special request, or order note.
7. **Discounts:** Optional fixed or percentage discount, controlled by Admin.
8. **Payment method:** Cash, UPI, Card, or Other, if useful to the shop.
9. **Duplicate bill:** Copy a saved bill into a new draft without changing the original.
10. **Daily summary:** Count of bills and total of saved bills, with a clear note that this is only a local-device summary and not a complete accounting system unless all sales are entered.
11. **Low-storage / backup reminder:** Warn users to export backups periodically.
12. **Dark mode:** Optional, not required for the first version.
13. **Tamil UI support:** Possible future enhancement.
14. **Keyboard support:** Useful for tablets and devices with a physical keyboard.
15. **Large text / compact mode:** Let the cashier choose a layout suited to their device.

### Features to defer unless actually needed
- Cloud sync and multi-device access (conflicts with the local-only requirement)
- Online payment processing
- Full inventory and stock tracking
- Customer accounts/credit ledger
- Full GST/accounting workflows
- Staff roles and remote permissions
- Automatic WhatsApp messaging without user confirmation

Do not add complicated features merely to make the app look larger. Prioritize reliable counter billing.

## 19. Complete Mobile Screen Inventory

Design these mobile screens and states consistently:

1. Home / category overview
2. Search results
3. Normal Sweets listing
4. Special Sweets listing
5. Karam & Savories listing
6. Top Rated Specials listing
7. Other Items listing
8. Product detail / weight-entry dialog
9. Product amount-entry mode
10. Fixed-price unit quantity dialog
11. Custom Item / Quick Add
12. Item added confirmation
13. Current Bill with items
14. Empty Current Bill
15. Edit Bill Item
16. Remove Item confirmation / Undo state
17. Clear Bill confirmation
18. New Bill confirmation
19. Save Bill Name
20. Bill Saved confirmation
21. Saved Bills list
22. Saved Bill actions
23. Invoice preview
24. Share options
25. WhatsApp contact picker (only if supported)
26. Manual phone number entry
27. PDF/image export state
28. Admin dashboard
29. Product management list
30. Add Product
31. Edit Product
32. Category management
33. Shop settings
34. Discount/payment settings (if enabled)
35. Backup/export data
36. Import backup preview and confirmation
37. Clear all local data confirmation
38. Validation/error states
39. Offline/local data status or backup reminder (optional)

All screens must use the same visual system and have coherent navigation. Design empty, success, error, and confirmation states, not only ideal happy-path screens.

## 20. Core User Journeys

### Journey A: Weight-based sale
Home → Special Sweets → Select Ghee Mysore Pak → Enter 8,800 g → Confirm 8.8 kg → Apply rate ₹280/kg → Amount ₹2,464 → Add to Bill → Continue adding products → Save Bill.

### Journey B: Customer asks for a fixed rupee amount
Home → Select Kaju Katli → Switch to Enter Amount → Enter ₹100 → Rate ₹900/kg → Show approximate weight 111.11 g → Preserve amount ₹100 → Add to Bill.

### Journey C: Miscellaneous snack not in catalog
Current Bill → Quick Add → Enter "Other Snack" → Choose Amount Only or enter a one-time rate/quantity → Enter ₹35 → Add to Bill. Optionally save it as a product in Other Items for future use.

### Journey D: Fixed-price packets
Other Items → Select Snack Packet → Enter 3 packets at ₹20 each → Total ₹60 → Add to Bill.

### Journey E: Temporary rate change
Select a product with default rate ₹280/kg → Change applied rate to ₹260/kg for this bill line → Calculate amount → Add to Bill. Admin's saved default remains ₹280/kg.

### Journey F: Start a new bill safely
Current Bill → New Bill → Save & Start New Bill → Enter bill name → Save → New empty draft appears. The old saved bill remains available.

### Journey G: Share invoice
Saved Bills → Select bill → Invoice preview → Share as PDF or image → Choose WhatsApp/contact if supported, or enter number manually → Confirm recipient and send in WhatsApp.

### Journey H: Admin updates product rate
Admin → Products → Edit product → Change default rate → Save. New bill lines use the new default; existing bill snapshots remain unchanged.

### Journey I: Backup and restore
Admin → Data Backup → Export JSON → Later choose Import → Preview backup → Choose safe merge/replace behavior → Confirm.

## 21. Suggested Build Phases

### Phase 1: Essential billing
- Categories and product listings
- Other Items category
- Weight-based billing in grams/kg
- Amount-based billing
- Fixed-price unit items
- Custom one-off amount item
- Temporary rate override
- Current bill editing and totals
- Save/resume bills
- IndexedDB persistence

### Phase 2: Invoices and admin
- Invoice preview
- PDF and image export
- WhatsApp share fallback flow
- Admin product/category management
- Shop settings
- Backup and restore

### Phase 3: Quality-of-life enhancements
- Preset weights and quick amounts
- Recent products
- Undo actions
- Optional discounts/payment methods/customer notes
- Local daily summary
- Tamil language support if wanted

Do not move to later phases until the core calculations and draft safety are tested.

## 22. Acceptance Checklist

The first usable release is ready only when these cases work:

- [ ] Opening the app shows the main categories, including Other Items.
- [ ] Admin can add any new category and product.
- [ ] Admin can configure a default rate/kg.
- [ ] A product can be billed by grams or kilograms.
- [ ] Entering 8,800 g displays 8.8 kg.
- [ ] Entering 8.8 kg displays 8,800 g.
- [ ] ₹280/kg × 8.8 kg calculates to ₹2,464.
- [ ] A temporary ₹260/kg override changes the current line but not the saved default.
- [ ] Entering an amount such as ₹100 calculates an approximate weight when a valid rate exists and preserves ₹100 as the line amount.
- [ ] An amount-only custom item can be added without a catalog rate.
- [ ] A fixed-price packet can be added using unit quantity.
- [ ] Other Items products can be predefined with rates or added ad hoc.
- [ ] Editing/removing a line recalculates the bill.
- [ ] Different applied rates are not merged in a way that loses their history.
- [ ] New Bill protects the existing draft.
- [ ] Saved bills persist after refresh/reopen.
- [ ] Product rate changes do not alter historical bills.
- [ ] Invoice preview includes the correct item details and totals.
- [ ] PDF/image export works in the target environment.
- [ ] WhatsApp sharing has a manual-number/export fallback and does not falsely claim that a message was sent.
- [ ] JSON backup can be exported and validated on import.
- [ ] Destructive actions require confirmation.
- [ ] Core billing works offline after the app is available locally.
- [ ] The app clearly warns that local data does not sync across devices and can be lost if browser data is cleared.

---

## Final Product Principle

Build Quality Sweets as a **fast, dependable local-first billing tool**. The cashier must be able to sell by weight, by rupee amount, by unit, or as a one-off custom item without fighting the interface. Admin defaults should speed up billing but never prevent a legitimate one-time price change. Bills must remain safe, totals must be correct, and invoices must be easy to share.
