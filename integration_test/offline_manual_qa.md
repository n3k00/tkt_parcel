# Offline MVP Manual QA

## 1. Create Parcel Without Internet

1. Turn off Wi-Fi and mobile data on the Android device.
2. Open `TKT Parcel`.
3. Create a parcel with valid sender, receiver, town, and charge data.
4. Move to voucher preview.
5. Confirm without print.

Expected:
- Parcel is saved successfully.
- No backend or internet error appears.
- Tracking ID is generated from local `cityCode` and `accountCode`.

## 2. Attach Parcel Image

1. Open create parcel form.
2. Pick an image from gallery or camera.
3. Move to voucher preview and save the parcel.
4. Open the saved parcel from history or reprint flow later.

Expected:
- The selected image path is stored locally.
- No remote URL is required.
- Parcel record remains valid offline.

## 3. Reopen App And Verify Local Persistence

1. Save at least one parcel locally.
2. Fully close the app from Android recent apps.
3. Reopen `TKT Parcel`.
4. Open parcel history.

Expected:
- The saved parcel is still visible.
- Latest parcels appear first.
- Search by tracking ID, receiver name, or phone still works.

## 4. Offline Print Validation

1. Keep internet off.
2. Connect to a paired thermal printer through the printer connect page.
3. Open voucher preview for a new or saved parcel.
4. Print the voucher.

Expected:
- Print uses locally rendered image output.
- Myanmar text remains readable because the receipt is image-based.
- If print fails, the parcel remains saved locally and can be reprinted.
