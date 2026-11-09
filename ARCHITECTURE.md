# Architecture

## Application structure

TKT Parcel is a Flutter Android application organized by feature. Entry points are `lib/main_dev.dart`, `lib/main_prod.dart`, and `lib/main.dart`; `lib/bootstrap.dart` initializes configuration and optional Supabase access before starting the app.

- `lib/app`: root app, routing, and shared providers.
- `lib/core`: configuration, theme, constants, platform services, printing, backup/restore, and common utilities.
- `lib/data`: Drift database, DAOs, models, mappers, repositories, local preferences, and server synchronization.
- `lib/features`: auth, parcels, vouchers, printing, printer setup, settings, and gate workflows.
- `lib/shared`: cross-feature models, helpers, and widgets.

Riverpod owns UI/application state. Screens consume providers; repositories coordinate local and remote data; services isolate platform and hardware behavior.

## Data and sync flow

Drift SQLite is the offline cache and local history store. Supabase is the authority for authenticated staff access, master data, official parcel creation, counters, and cross-device synchronization. Current pull sync is server-to-local. Creating an official parcel is online-only because the server RPC assigns its tracking ID.

## Printing flow

Voucher and parcel-label widgets are rendered to images so Myanmar text is preserved before sending printer commands. `ParcelLabelPreview` is shared by settings preview, test print, and actual reprint. Label stock presets define physical TSPL dimensions and pixel canvases; layout changes must be verified at those exact dimensions.

Printer discovery/connection remains in `pos_printer_kit`; the app wraps navigation with its permission helper instead of maintaining a second connection UI.
