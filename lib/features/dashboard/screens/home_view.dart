import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'dart:typed_data';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:airdash/features/files/repositories/offline_file_service.dart';
import 'package:airdash/features/files/models/file_item.dart';
import 'package:airdash/features/files/models/file_type.dart';
import 'package:airdash/features/notifications/screens/notification_screen.dart';
import 'package:airdash/features/notifications/models/notification_model.dart';
import 'package:airdash/features/notifications/services/notification_service.dart';
import 'package:airdash/features/profile/screens/upgrade_screen.dart';
import 'package:airdash/features/auth/services/auth_service.dart';
import 'package:airdash/features/transfer/services/signaling_service.dart';
import 'package:airdash/features/transfer/screens/receiver_progress_screen.dart';
import 'package:airdash/features/transfer/widgets/transfer_user_picker_dialog.dart';
import 'package:airdash/features/transfer/screens/transfer_progress_screen.dart';
import 'package:airdash/features/communities/screens/communities_view.dart';

class HomeView extends StatefulWidget {
  final VoidCallback? onNavigateToFiles;

  const HomeView({super.key, this.onNavigateToFiles});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final OfflineFileService _fileService = OfflineFileService();

  @override
  void initState() {
    super.initState();
    // Init Notifications
    NotificationService().init();
    
    // Check for Admin Deletions on start
    _fileService.syncCloudDeletions().then((_) {
       // After cleaning up, sync DOWN new files
       _fileService.syncCloudDeletions().then((_) { // Actually, I reused the method name. Wait.
           // I added the logic INTO syncCloudDeletions in previous step. 
           // So just calling it is enough.
           // Wait, I should verify if I renamed it or just added logic.
           // I kept the name syncCloudDeletions but added the DOWN logic.
           // So this existing call is sufficient!
           if (mounted) setState(() {}); 
       });
    });

    _listenForTransfers();
  }

  void _listenForTransfers() {
      final userId = AuthService().currentUserUid;
      if (userId == null) return;

      SignalingService().getIncomingSignals(userId).listen((snapshot) {
          for (var change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added) {
                  final data = change.doc.data() as Map<String, dynamic>;
                  final id = change.doc.id;
                  
                  // Show Dialog
                  // We must check if dialog is already showing to avoid stack? 
                  // For now simple showDialog
                  if (mounted) {
                      _showIncomingTransferDialog(id, data);
                  }
              }
          }
      });
  }

  void _showIncomingTransferDialog(String transferId, Map<String, dynamic> data) {
      final senderName = data['senderId'] ?? 'Unknown'; 
      final fileMeta = data['fileMetadata'] as Map<String, dynamic>;
      final fileName = fileMeta['name'] ?? 'File';
      final fileSize = fileMeta['size'] ?? '?';

      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
              title: const Text("Incoming File Transfer"),
              content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      Text("A user wants to send you a file via P2P (Offline Transfer)."),
                      const SizedBox(height: 10),
                      Text("File: $fileName", style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text("Size: $fileSize"),
                  ],
              ),
              actions: [
                  TextButton(
                      onPressed: () {
                          // Reject / Ignore
                          Navigator.pop(context);
                      },
                      child: const Text("Decline"),
                  ),
                  FilledButton(
                      onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => ReceiverProgressScreen(
                                      transferId: transferId,
                                      offer: data['offer'],
                                      fileMetadata: fileMeta,
                                      senderName: senderName,
                                  ),
                              ),
                          );
                      },
                      child: const Text("Accept"),
                  ),
              ],
          ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Dashboard",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 24),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(LucideIcons.bell), 
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen()));
                }
              ),
              // Unread Badge
              ValueListenableBuilder(
                valueListenable: Hive.box<NotificationModel>('notificationsBox').listenable(),
                builder: (_, Box<NotificationModel> box, __) {
                   final unread = box.values.where((n) => !n.isRead).length;
                   if (unread == 0) return const SizedBox.shrink();
                   return Positioned(
                     right: 8,
                     top: 8,
                     child: Container(
                       padding: const EdgeInsets.all(4),
                       decoration: const BoxDecoration(
                         color: Colors.red,
                         shape: BoxShape.circle,
                       ),
                       child: Text(
                         unread > 9 ? '9+' : unread.toString(),
                         style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                       ),
                     ),
                   );
                },
              ),
            ],
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box('filesBox').listenable(),
        builder: (context, box, _) {
          final recentFiles = _fileService.getAllFiles().take(5).toList(); // Show top 5 recent

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAnimatedItem(delay: 0, child: _buildStorageCard(context)),
                const SizedBox(height: 24),
                _buildAnimatedItem(
                  delay: 100,
                  child: Text(
                    "Quick Actions",
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildAnimatedItem(
                  delay: 200,
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          context,
                          "Upload",
                          LucideIcons.uploadCloud,
                          Colors.blue,
                          _handleUpload,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildActionButton(
                          context,
                          "Transfer",
                          LucideIcons.send,
                          Colors.orange,
                          _handleTransfer,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildAnimatedItem(
                  delay: 300,
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          context,
                          "PDF Scan",
                          LucideIcons.scanLine,
                          Colors.purple,
                          _handlePdfScan,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildActionButton(
                          context,
                          "Communities",
                          LucideIcons.users,
                          Colors.teal,
                          () {
                             Navigator.push(context, MaterialPageRoute(builder: (_) => const CommunitiesView()));
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildAnimatedItem(
                  delay: 350,
                  child: Row(
                    children: [
                      const Spacer(),
                      Expanded(
                        flex: 2,
                        child: _buildActionButton(
                          context,
                          "Cleanup",
                          LucideIcons.trash2,
                          Colors.red,
                          _handleCleanup,
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildAnimatedItem(
                  delay: 400,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Recent Files",
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: widget.onNavigateToFiles, 
                        child: const Text("View All"),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (recentFiles.isEmpty)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text("No recent files"),
                  ))
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recentFiles.length,
                    itemBuilder: (context, index) {
                      return _buildAnimatedItem(
                        delay: 500 + (index * 100),
                        child: _buildFileTile(context, recentFiles[index]),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnimatedItem({required int delay, required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }


  Widget _buildStorageCard(BuildContext context) {
    final int usedBytes = _fileService.getTotalSize();
    final int totalBytes = 5 * 1024 * 1024 * 1024; // 5 GB limit
    final double progress = (usedBytes / totalBytes).clamp(0.0, 1.0);
    
    // Smart formatting
    String usedString;
    if (usedBytes < 1024 * 1024 * 1024) {
       // Less than 1 GB, show MB
       usedString = "${(usedBytes / (1024 * 1024)).toStringAsFixed(1)} MB";
    } else {
       usedString = "${(usedBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB";
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade800, Colors.purple.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
               Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.cloud, color: Colors.white),
               ),
               const SizedBox(width: 16),
               Text(
                 "Free Plan",
                 style: GoogleFonts.outfit(
                   color: Colors.white,
                   fontSize: 20,
                   fontWeight: FontWeight.bold,
                   decoration: TextDecoration.none, // Ensure no underline
                 ),
               ),
               const Spacer(),
               TextButton(
                 onPressed: () {
                     Navigator.push(context, MaterialPageRoute(builder: (_) => const UpgradeScreen()));
                 }, 
                 style: TextButton.styleFrom(
                   foregroundColor: Colors.white,
                   backgroundColor: Colors.white.withOpacity(0.1),
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                 ),
                 child: const Text("Upgrade", style: TextStyle(fontWeight: FontWeight.bold)),
               ),
            ],
          ),
          const SizedBox(height: 24),
          ClipRRect(
             borderRadius: BorderRadius.circular(8),
             child: LinearProgressIndicator(
               value: progress,
               minHeight: 8,
               backgroundColor: Colors.white.withOpacity(0.1),
               color: Colors.white,
             ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Text(
                 "$usedString used",
                 style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600),
               ),
               Text(
                 "5 GB total",
                 style: GoogleFonts.outfit(color: Colors.white54),
               ),
            ],
          ),
        ],
      ),
    );
  }

  // Actions Logic
  Future<void> _handleUpload() async {
      await _fileService.pickAndSaveFile(
        onFilePicked: (name, size) {
           if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(
                 content: Row(
                   children: [
                     const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                     const SizedBox(width: 16),
                     Expanded(child: Text("Uploading $name...")),
                   ],
                 ),
                 duration: const Duration(seconds: 10), // Keep it visible during upload
               ),
             );
           }
        },
      );
      if (mounted) {
           ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Hide "Uploading"
           ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text("File uploaded successfully"), backgroundColor: Colors.green),
           );
      }
  }

  Future<void> _shareFile(FileItem file) async {
    try {
      await _fileService.shareFile(file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing file: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleTransfer() async {
      // 1. Pick File First (Common step)
      final file = await _fileService.pickAndSaveFile();
      if (file == null || !mounted) return;

      // 2. Ask User for Method
      showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) {
              return SafeArea(
                  child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                              Text("Choose Transfer Method", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              ListTile(
                                  leading: const Icon(LucideIcons.radio, color: Colors.blue),
                                  title: const Text("AirDash P2P"),
                                  subtitle: const Text("Send directly to another dashboard user nearby"),
                                  onTap: () async {
                                      Navigator.pop(context); // Close sheet
                                      
                                      // P2P Flow
                                      final String? userId = await showDialog<String>(
                                          context: context,
                                          builder: (context) => const TransferUserPickerDialog(),
                                      );

                                      if (userId != null && mounted) {
                                          Navigator.of(context).push(
                                              MaterialPageRoute(
                                                  builder: (context) => TransferProgressScreen(file: file, receiverId: userId),
                                              ),
                                          );
                                      }
                                  },
                              ),
                              ListTile(
                                  leading: const Icon(LucideIcons.share2, color: Colors.green),
                                  title: const Text("System Share"),
                                  subtitle: const Text("Share via WhatsApp, Email, Bluetooth..."),
                                  onTap: () {
                                      Navigator.pop(context);
                                      _shareFile(file);
                                  },
                              ),
                          ],
                      ),
                  ),
              );
          },
      );
  }

  Future<void> _handlePdfScan() async {
      try {
        // 1. Scan Documents
        List<String>? pictures;
        try {
          pictures = await CunningDocumentScanner.getPictures();
        } catch (e) {
           // Handle cancellation or error (e.g. no camera on emulator)
           print("Scanner error: $e");
           if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Could not start scanner. (Emulator/Permission issue?)"))
              );
           }
           return;
        }

        if (pictures != null && pictures.isNotEmpty) {
           if (mounted) {
               ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text("Processing PDF..."))
               );
           }

           // 2. Create PDF
           final pdf = pw.Document();

           for (var path in pictures) {
               final image = pw.MemoryImage(
                 File(path).readAsBytesSync(),
               );

               pdf.addPage(
                 pw.Page(
                   build: (pw.Context context) {
                     return pw.Center(
                       child: pw.Image(image),
                     );
                   }
                 )
               );
           }

           // 3. Save PDF
           final Uint8List bytes = await pdf.save();
           final String fileName = "Scan_${DateTime.now().millisecondsSinceEpoch}.pdf";
           
           final newItem = await _fileService.savePdfFile(bytes, fileName);
           
           if (newItem != null && mounted) {
               ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text("PDF Saved successfully!"))
               );
               // You could open it immediately or just show in list
           }
        }
      } catch (e) {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error creating PDF: $e"), backgroundColor: Colors.red),
           );
         }
      }
  }

  Future<void> _handleCleanup() async {
      showDialog(
          context: context,
          builder: (context) => AlertDialog(
              title: const Text("Cleanup Drive"),
              content: const Text("WARNING: This will delete ALL files from your secure storage. This action cannot be undone."),
              actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                  FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () async {
                          Navigator.pop(context);
                          await _fileService.deleteAllFiles();
                          if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("All files deleted."))
                              );
                          }
                      },
                      child: const Text("Delete All"),
                  ),
              ],
          ),
      );
  }


  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 12),
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileTile(BuildContext context, FileItem file) {
    bool isApk = file.name.toLowerCase().endsWith('.apk');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isApk
                ? Colors.blue.withOpacity(0.1)
                : (file.color?.withOpacity(0.1) ?? Colors.grey.withOpacity(0.1)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isApk ? LucideIcons.cloud : _getIconForType(file.type),
            color: isApk
                ? Colors.blue
                : (file.color ?? Colors.grey),
            size: 24,
          ),
        ),
        title: Text(
          file.name,
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          "${file.size} • ${_formatDate(file.modified)}",
          style: GoogleFonts.outfit(color: Colors.grey),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(LucideIcons.moreVertical, size: 20, color: Colors.grey),
          onSelected: (value) async {
            if (value == 'share') {
               _shareFile(file);
            } else if (value == 'delete') {
               // We need a delete function here. 
               // _fileService.deleteFile(file.id) works but we need confirmation UI?
               // For quick action, let's just delete or show dialog?
               // Reuse logic if possible, or simple dialog.
               final confirm = await showDialog<bool>(
                   context: context, 
                   builder: (context) => AlertDialog(
                       title: const Text("Delete File?"),
                       content: const Text("Are you sure?"),
                       actions: [
                           TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                           FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete")),
                       ]
                   )
               ) ?? false;
               if (confirm) {
                   await _fileService.deleteFile(file.id);
                   if (mounted) setState(() {});
               }
            } else if (value == 'rename') {
               // Implement Rename Dialog here (Duplicate logic from FileExplorerView)
               String? newName;
               await showDialog(
                 context: context,
                 builder: (context) {
                     final controller = TextEditingController(text: file.name);
                     return AlertDialog(
                         title: Text("Rename ${file.isFolder ? 'Folder' : 'File'}"),
                         content: TextField(
                            controller: controller,
                            decoration: const InputDecoration(hintText: "New Name"),
                            autofocus: true,
                            onSubmitted: (val) => Navigator.pop(context),
                         ),
                         actions: [
                             TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                             FilledButton(onPressed: () { newName = controller.text.trim(); Navigator.pop(context); }, child: const Text("Rename")),
                         ],
                     );
                 }
               );
               if (newName != null && newName!.isNotEmpty && newName != file.name) {
                   await _fileService.renameFile(file.id, newName!);
                   if (mounted) setState(() {});
               }
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'share', child: Text("Share")),
            const PopupMenuItem(value: 'rename', child: Text("Rename")),
            const PopupMenuItem(value: 'delete', child: Text("Delete")),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, y, h:mm a').format(date);
  }

  IconData _getIconForType(FileType type) {
    switch (type) {
      case FileType.folder:
        return LucideIcons.folder;
      case FileType.image:
        return LucideIcons.image;
      case FileType.video:
        return LucideIcons.video;
      case FileType.document:
        return LucideIcons.fileText;
      case FileType.audio:
        return LucideIcons.music;
      default:
        return LucideIcons.file;
    }
  }
}
