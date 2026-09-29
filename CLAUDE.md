# flow_columns — ngữ cảnh bàn giao sang dự án riêng

Tài liệu này là toàn bộ ngữ cảnh để tiếp tục phát triển package `flow_columns` trong một
repo mới, độc lập với app KDS. Copy nó làm `CLAUDE.md` của repo mới.

## 1. Nguồn gốc và mục tiêu

- Package tách từ tính năng "Dynamic view tràn cột" của app Flutter BlogicKDS (kitchen display).
  Bản gốc nằm ở repo `app-kds`, nhánh `feature/flow-columns-package`, commit `167a508`, thư mục
  `BlogicKDS/packages/flow_columns/`. Copy nguyên thư mục đó sang repo mới:
  `cp -R BlogicKDS/packages/flow_columns/. <repo-mới>/`
- Mục tiêu: publish lên pub.dev với tên `flow_columns`. Chưa có package Flutter nào làm việc
  "cắt một card thành nhiều mảnh và chảy tiếp sang cột kế" (CSS `column-count` cho widget).
- Bài toán gốc: màn bếp hiển thị ticket theo cột cố định, ticket dài phải chảy sang cột kế thay
  vì scroll trong card, nhưng KHÔNG BAO GIỜ cắt giữa một món và modifier/note của nó.

## 2. Trạng thái hiện tại

Đã xong và xanh:

- `lib/src/column_flow_packer.dart`: `packColumnFlow(...)` thuần Dart, chỉ phụ thuộc `dart:ui`.
- `lib/src/flow_columns_board.dart`: `FlowColumnsBoard`, `RenderFlowColumnsBoard`,
  `FlowFragment`, `FlowCardStyle`, `FlowBandStyle`, `FlowColumnsParentData`.
- `lib/flow_columns.dart` export hai file trên.
- Test: `test/column_flow_packer_test.dart` (14 case), `test/flow_columns_board_test.dart`
  (10 case widget test bằng hộp màu thuần). 24/24 pass.
- `README.md` (tiếng Anh, có hướng dẫn dùng), `CHANGELOG.md` 0.2.0, `LICENSE` MIT
  "Copyright (c) 2026 Lam Le", `example/` (chỉ `pubspec.yaml` + `lib/main.dart`, chưa có platform
  folder; chạy `flutter create .` trong `example/` khi cần).
- `dart pub publish --dry-run`: 0 warning. `flutter analyze` sạch, `dart format` sạch.
- Chỉ phụ thuộc `flutter`; dev: `flutter_test`, `flutter_lints ^5.0.0`. SDK `^3.9.2`,
  Flutter `>=3.22.0` (đang dev trên Flutter 3.44.9).

Chưa làm / cần user quyết:

- 0.2.0 là bản đầu tiên trên pub.dev (29-09-2026), tag `v0.2.0`; 0.1.0 chỉ có tag git, chưa từng
  lên pub.dev. Publish bằng `dart pub publish`, user tự chạy vì cần đăng nhập Google.
- App KDS chưa tích hợp package (user bảo làm package trước, tích hợp sau). Việc tích hợp thuộc
  repo app, không phải repo này.

## 3. API đã chốt với user (không đổi tên nếu không hỏi)

- Tên package: `flow_columns`.
- Ba loại mảnh `FlowFragmentKind { head, item, tail }`:
  - `head`: mở card; mọi head của một card và item đầu tiên đi cùng nhau, không đủ chỗ thì cả
    card sang cột kế (quy tắc "header mồ côi"). Trong app KDS: header, sale band, fire band.
  - `item`: điểm duy nhất được phép cắt. Một item không bao giờ bị cắt. Item cao hơn chỗ trống
    còn lại thì bị cap và scroll bên trong.
  - `tail`: đóng card, luôn cùng cột với item cuối. Trong app KDS: footer trạng thái.
- `packColumnFlow({fragments, heights, cards, columnWidth, columnHeight, spacing, border=2,
  continuedBandHeight=36, continuedFooterHeight=36, cutPadding=8, continuedTopPadding=8})`
  → `FlowPackResult{offsets, layoutHeights, runs, usedColumns, width, hasOverflow}`.
  `FlowRun{cardIndex, column, top, bottom, isContinuation, continues, lockedOverlayBottom,
  fragmentStart, fragmentEnd (nửa mở)}`.
- `FlowColumnsBoard({cards: List<FlowCardStyle>, columnWidth, columnHeight, spacing,
  borderWidth=2, radius=16, fillColor=white, lockOverlayColor=grey 50%, topBand, bottomBand
  (FlowBandStyle), showTopBand=true, showBottomBand=true, continuedLabel='Continued...',
  cutPadding=8, continuedTopPadding=8, children})`. `showTopBand`/`showBottomBand` false → band
  không vẽ và không chiếm chỗ (packer nhận chiều cao band = 0), `cutPadding`/`continuedTopPadding`
  vẫn áp dụng; `debugContinuedLabel` trả null khi top band ẩn.
  Text direction và text scaler lấy từ context, không truyền.
- `FlowFragment({cardIndex, kind, leadingGap=0, continuedLabel='', child})`. Loại `item` tự bọc
  `Scrollbar > SingleChildScrollView` dọc. `continuedLabel` rỗng → dùng nhãn của board.
- `FlowCardStyle({borderColor, isLocked=false, trailingGap})`. `isLocked` CHỈ vẽ overlay, chặn
  chạm là việc của người dùng (bọc `AbsorbPointer`).
- `FlowBandStyle({height=36, color=0xFFF5F5F5, textStyle (16 bold đen), textInset=12})`.
- `@visibleForTesting`: `RenderFlowColumnsBoard.debugRuns`, `debugContinuedLabel(run)`.

## 4. Quy tắc thuật toán (bản logic cuối)

- Cột cố định `columnWidth × columnHeight`, xếp từ trên xuống, đầy thì sang cột bên phải; board
  rộng = số cột dùng, thường đặt trong `SingleChildScrollView` ngang.
- Card không vừa chỗ còn lại thì cắt SAU item cuối còn vừa. Mảnh bị cắt kết thúc bằng band đáy
  (cao `continuedFooterHeight`, cách item trên `cutPadding`); mảnh tiếp mở bằng band đầu (cao
  `continuedBandHeight`) rồi `continuedTopPadding`, KHÔNG cộng `leadingGap` của item.
- Một item chỉ được đặt ở cột hiện tại nếu còn chỗ cho cả nó và band đáy (`closeAfter`), trừ
  item cuối: khi đó phải còn chỗ cho cả tail (nếu có) và `trailingGap + border` (`closeBudget`).
- Tail luôn đi cùng item cuối, không bao giờ đứng một mình đầu cột.
- Quy tắc mồ côi chỉ áp dụng khi cột đã có nội dung (`y > 0`); cột trống luôn nhận card.
- Item cao hơn chỗ trống (kể cả ở cột trống): cap `layoutHeights[f] = columnHeight - y -
  closeBudget(f)`, run vẫn kết thúc đúng tại đáy cột, item sau chắc chắn sang cột kế. Chỉ head/tail
  cao hơn cột mới đặt rồi clip và `hasOverflow = true`.
- Overlay lock phủ từ viền trong trên đến: hết band đáy nếu run bị cắt; mép trên tail nếu run
  cuối có tail; viền trong dưới nếu không có tail.
- Nhãn: band đáy luôn `continuedLabel` của board; band đầu lấy `continuedLabel` của mảnh mở
  phần tiếp, rỗng thì của board. (App KDS chỉ đặt nhãn riêng "Split #N · Continued" cho split
  card; ticket fire dùng nhãn mặc định — quyết định của user 29-09-2026.)

## 5. Bẫy kỹ thuật đã gặp, đừng lặp lại

- **Không layout thật item với chiều cao tự do rồi layout lại.** Viewport của scroll view sẽ
  bằng nội dung và reset scroll offset về 0 ở mỗi lần board re-layout (app có timer mỗi giây).
  Render đo `item` bằng `getDryLayout`, layout thật đúng một lần với chiều cao tight khi bị cap.
  Hệ quả: item không được chứa widget không dry layout được (`LayoutBuilder`…); head/tail thì
  layout thật nên được phép. Đã ghi trong README.
- **Lấy lại `context.canvas` sau `paintChild`.** Mảnh item có `RepaintBoundary` (từ `Scrollbar`)
  nên là composited child; `paintChild` kết thúc bản ghi canvas trước đó, dùng canvas cũ để vẽ
  overlay/viền sẽ crash "native peer has been collected".
- **Widget test kéo item bị cap:** sau `tester.drag` phải `pump(Duration(seconds: 1))` để fling
  và timer fade của Scrollbar kết thúc, nếu không test báo "Timer is still pending".
- `TextPainter` band cache theo `(label, FlowBandStyle)`, xả khi đổi bề rộng cột, viền, style,
  text direction, text scaler.
- Đổi `trailingGap` hay số card → `markNeedsLayout`; đổi màu/nhãn → chỉ `markNeedsPaint`.

## 6. Việc có thể làm tiếp (chưa được yêu cầu, hỏi trước khi làm)

- Bản kế tiếp: bump version + CHANGELOG, publish, tag.
- Ảnh/GIF minh họa cho README (pub.dev hiển thị tốt hơn ASCII).
- Platform folder cho `example/` nếu muốn chạy ngay.
- CI (GitHub Actions: analyze + test).
- Tùy chọn: cho phép tắt scroll wrapper của item; `AbsorbPointer` tự động khi `isLocked`;
  band có builder widget thay vì chỉ text.

## 7. Cách làm việc user muốn

- Trả lời và viết tài liệu/plan bằng tiếng Việt; README và code/comment tiếng Anh.
- Trước khi code tính năng mới: nêu thiết kế ngắn trong chat, hỏi bằng câu văn ở cuối, chờ ok.
  Câu hỏi cộc lốc của user là câu hỏi, không phải lệnh.
- Code không thêm comment inline giải thích; giải thích để trong doc/README. Doc là bản logic
  cuối, không ghi lịch sử.
- Chỉ commit khi user nói "commit". Không push nếu không được bảo.
- Thay đổi tối thiểu, không refactor ngoài phạm vi yêu cầu.
- Mỗi thay đổi phải qua `flutter analyze` 0 lỗi, `flutter test`, `dart format`; viết test trước
  khi sửa logic packer/render.

## 8. Lệnh

```bash
flutter pub get
flutter analyze
flutter test
dart format lib test example
dart pub publish --dry-run
dart pub publish
```
