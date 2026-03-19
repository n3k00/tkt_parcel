# Printer Manual QA Checklist

## Device Requirements

- Android phone with Bluetooth
- Paired thermal printer supported by `pos_printer_kit`
- One printable voucher with Myanmar text content

## Manual Scenarios

### 1. Bluetooth Off Error

1. Turn Bluetooth off on the Android device.
2. Open printer connect flow from the Home screen Bluetooth icon.
3. Attempt to search/connect/print.
4. Verify the app shows a user-friendly Bluetooth-off error.

### 2. Successful Connect

1. Turn Bluetooth on.
2. Open printer connect page.
3. Select a paired printer and connect.
4. Return to Home screen.
5. Verify Bluetooth icon changes to connected state.

### 3. Successful Image Print

1. Open a voucher preview with Myanmar text.
2. Tap `Confirm and Print`.
3. Verify printed voucher is readable and centered.
4. Verify success message appears in the app.

### 4. Disconnected During Print

1. Start printing a voucher.
2. Power off the printer or force disconnect during write.
3. Verify app shows print failure and latest error.
4. Verify `Retry Print` is available.

### 5. Retry After Failure

1. Trigger a print failure.
2. Tap `Retry Print`.
3. Verify the same voucher image is sent again after reconnecting.

### 6. Reprint Last Voucher

1. Complete at least one successful print.
2. Tap `Reprint Last Voucher`.
3. Verify the same voucher image prints again.

### 7. Myanmar Text Image Print

1. Use a voucher containing Myanmar text in sender/receiver/remark fields.
2. Print the voucher.
3. Verify glyph rendering is correct and no ESC/POS text corruption occurs.
