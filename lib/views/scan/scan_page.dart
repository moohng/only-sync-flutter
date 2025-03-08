import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  late MobileScannerController controller;

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('扫描二维码'),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: controller,
              builder: (context, state, child) {
                if (state.torchState == TorchState.on) {
                  return const Icon(Icons.flash_on);
                }
                return const Icon(Icons.flash_off);
              },
            ),
            onPressed: () => controller.toggleTorch(),
          ),
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: controller,
              builder: (context, state, child) {
                switch (state.cameraDirection) {
                  case CameraFacing.front:
                    return const Icon(Icons.camera_front);
                  default:
                    return const Icon(Icons.camera_rear);
                }
              },
            ),
            onPressed: () => controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  // 找到有效的二维码后返回结果
                  Get.back(result: barcode.rawValue);
                  return;
                }
              }
            },
            errorBuilder: (context, error, child) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      _getErrorMessage(error.errorCode),
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              );
            },
          ),
          // 扫描框
          CustomPaint(
            painter: ScannerOverlay(),
            child: Container(),
          ),
        ],
      ),
    );
  }

  String _getErrorMessage(MobileScannerErrorCode errorCode) {
    switch (errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return '请授予相机权限以使用扫描功能';
      case MobileScannerErrorCode.unsupported:
        return '此设备不支持扫描功能';
      default:
        return '扫描器初始化失败，请检查相机权限';
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

// 自定义扫描框绘制
class ScannerOverlay extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.fill;

    final scanAreaSize = size.width * 0.7;
    final scanAreaLeft = (size.width - scanAreaSize) / 2;
    final scanAreaTop = (size.height - scanAreaSize) / 2;

    // 绘制半透明背景
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()
          ..addRect(Rect.fromLTWH(
            scanAreaLeft,
            scanAreaTop,
            scanAreaSize,
            scanAreaSize,
          )),
      ),
      paint,
    );

    // 绘制扫描框边框
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRect(
      Rect.fromLTWH(
        scanAreaLeft,
        scanAreaTop,
        scanAreaSize,
        scanAreaSize,
      ),
      borderPaint,
    );

    // 绘制角标
    final cornerSize = scanAreaSize * 0.1;
    final cornerPaint = Paint()
      ..color = Theme.of(Get.context!).primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    // 左上角
    canvas.drawPath(
      Path()
        ..moveTo(scanAreaLeft, scanAreaTop + cornerSize)
        ..lineTo(scanAreaLeft, scanAreaTop)
        ..lineTo(scanAreaLeft + cornerSize, scanAreaTop),
      cornerPaint,
    );

    // 右上角
    canvas.drawPath(
      Path()
        ..moveTo(scanAreaLeft + scanAreaSize - cornerSize, scanAreaTop)
        ..lineTo(scanAreaLeft + scanAreaSize, scanAreaTop)
        ..lineTo(scanAreaLeft + scanAreaSize, scanAreaTop + cornerSize),
      cornerPaint,
    );

    // 右下角
    canvas.drawPath(
      Path()
        ..moveTo(scanAreaLeft + scanAreaSize, scanAreaTop + scanAreaSize - cornerSize)
        ..lineTo(scanAreaLeft + scanAreaSize, scanAreaTop + scanAreaSize)
        ..lineTo(scanAreaLeft + scanAreaSize - cornerSize, scanAreaTop + scanAreaSize),
      cornerPaint,
    );

    // 左下角
    canvas.drawPath(
      Path()
        ..moveTo(scanAreaLeft + cornerSize, scanAreaTop + scanAreaSize)
        ..lineTo(scanAreaLeft, scanAreaTop + scanAreaSize)
        ..lineTo(scanAreaLeft, scanAreaTop + scanAreaSize - cornerSize),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
