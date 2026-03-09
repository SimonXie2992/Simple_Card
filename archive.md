# Archived Tasks

## Completed
### Batch 3
1. ✅ 管理图标改回方块 → Cards tab icon changed to `Icons.grid_view` (grid block shape)
2. ✅ 动态对齐框自动调整 → Smooth corner interpolation (35% lerp blend), auto-capture after 1.5s stability, green progress indicator, dynamic frame turns green when locked
3. ✅ 图片增亮增白 → CIFilter pipeline: CIColorControls (brightness +0.05, contrast 1.15, saturation 0.9) + CIHighlightShadowAdjust (shadows +0.3) + CIExposureAdjust (+0.3 EV)

### Batch 2
1. ✅ 拍照界面-静态对齐框盖住按钮 → Frame dynamically positioned between topbar and bottom controls, max height constrained
2. ✅ 动态对齐误识别 → Consecutive hit/miss thresholds (3 hits to show, 5 misses to hide) + native confidence raised to 0.6
3. ✅ 横向/纵向名片优化 → VNDetectRectanglesRequest handles both orientations; aspect ratio classification distinguishes card vs document
4. ✅ 确认界面预览压缩 → Preview uses `BoxFit.contain` for correct proportions
5. ✅ Card review预览角度 → Preview uses `BoxFit.contain`; tap opens full-screen `InteractiveViewer` with pinch-zoom
6. ✅ 相机启动慢 → Deferred stream start (300ms delay) so camera preview shows instantly

### Batch 1
- ✅ All items resolved in previous sessions
## Batch 4
- 1.OCR识别：我需要支持英文、日文、中文的识别
- 2.OCR识别：目前识别算法存在问题、扫描完后无法准确识别姓名、公司名、部门、职务、电话、传真、邮箱、web等信息
- 3.名片导入与导出功能不可用、点击后显示coming soon，很多功能也是这样
- 4.名片详情页：我需要在扫描名片预览页面自动（黄底）标示出识别到的部分
- 5.名片详情页：我需要支持手动修改识别到的信息
