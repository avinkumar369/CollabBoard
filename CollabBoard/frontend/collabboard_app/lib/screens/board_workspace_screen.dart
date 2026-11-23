import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/board.dart';
import '../models/canvas_tool.dart';
import '../models/canvas_object.dart';
import '../models/canvas_object_move.dart';
import '../providers/collaboration_provider.dart';
import '../services/api_service.dart';
import '../widgets/whiteboard_painter.dart';
import '../utils/board_exporter.dart';
import '../widgets/share_dialog.dart';

class BoardWorkspaceScreen extends StatefulWidget {
  final Board board;

  const BoardWorkspaceScreen({super.key, required this.board});

  @override
  State<BoardWorkspaceScreen> createState() =>
      _BoardWorkspaceScreenState();
}

class _BoardWorkspaceScreenState extends State<BoardWorkspaceScreen> {
final TransformationController _transformationController =
TransformationController();

// Identifies the actual canvas, not the entire screen.
final GlobalKey _canvasKey = GlobalKey();

double _currentScale = 1.0;

List<Offset> _currentPath = [];
Offset? _startPoint;

bool _isSavingStatus = false;
bool _showPropertiesPanel = true;
bool _didApplyInitialPanelVisibility = false;
double _panTravel = 0;

/// Database id of the object selected with the Select tool.
int? _selectedObjectId;

// Drag-to-move state for the Select tool.
Offset? _dragOrigin;
CanvasObject? _dragSource;
CanvasObject? _dragPreview;

/// Fixed extent of the drawing surface. The canvas is no longer limited to
/// one screen: pan and zoom out to reach the rest of it.
static const Size _canvasSize = Size(4000, 4000);

/// Visible area, used to zoom around the centre of the screen.
Size _viewportSize = Size.zero;

// Throttle for broadcasting this device's pointer.
DateTime _lastCursorSent = DateTime.fromMillisecondsSinceEpoch(0);

@override
void initState() {
super.initState();

_transformationController.addListener(_onTransformationChanged);

WidgetsBinding.instance.addPostFrameCallback((_) {
if (!mounted) return;

Provider.of<CollaborationProvider>(
context,
listen: false,
).initBoard(widget.board.id);
});
}

@override
void didChangeDependencies() {
super.didChangeDependencies();

// Only decide the initial visibility once. MediaQuery changes whenever
// the keyboard opens, which would otherwise keep hiding the panel.
if (_didApplyInitialPanelVisibility) return;

_didApplyInitialPanelVisibility = true;

if (MediaQuery.of(context).size.width < 600) {
_showPropertiesPanel = false;
}
}

@override
void dispose() {
_transformationController.removeListener(_onTransformationChanged);
_transformationController.dispose();
super.dispose();
}

void _onTransformationChanged() {
if (!mounted) return;

final scale =
_transformationController.value.getMaxScaleOnAxis();

if (scale != _currentScale) {
setState(() {
_currentScale = scale;
});
}
}

void _zoomIn() {
_setZoom((_currentScale + 0.2).clamp(0.25, 3.0));
}

void _zoomOut() {
_setZoom((_currentScale - 0.2).clamp(0.25, 3.0));
}

void _setZoom(double scale) {
final double target = scale.clamp(0.25, 3.0).toDouble();

// Zoom around the centre of the canvas. Rebuilding the matrix from
// scratch would discard the current pan offset and snap the view back
// to the top-left corner.
// The canvas is much larger than the screen now, so the focal point must
// come from the viewport, not from the canvas RenderBox.
final Size viewport = _viewportSize == Size.zero
? MediaQuery.of(context).size
: _viewportSize;
final Offset focal = Offset(viewport.width / 2, viewport.height / 2);

final double current =
_transformationController.value.getMaxScaleOnAxis();
final double factor = current == 0 ? 1.0 : target / current;

final Matrix4 zoom = Matrix4.translationValues(focal.dx, focal.dy, 0)
.multiplied(Matrix4.diagonal3Values(factor, factor, 1.0))
.multiplied(Matrix4.translationValues(-focal.dx, -focal.dy, 0));

_transformationController.value =
zoom.multiplied(_transformationController.value);
}

// IMPORTANT:
// Convert using the actual canvas RenderBox.
// globalToLocal already accounts for InteractiveViewer transforms.
// Do not apply the inverse transformation a second time.
Offset _getLocalPosition(Offset global) {
final render =
_canvasKey.currentContext?.findRenderObject();

if (render is RenderBox) {
return render.globalToLocal(global);
}

return global;
}

void _markSaving() {
if (!mounted) return;

setState(() {
_isSavingStatus = true;
});

Future.delayed(const Duration(milliseconds: 1500), () {
if (mounted) {
setState(() {
_isSavingStatus = false;
});
}
});
}

// Handle simple canvas taps.
// PanStart alone does not detect a normal tap.
void _handleCanvasTap(
TapDownDetails details,
CollaborationProvider collab,
) {
final tool = collab.selectedTool;
final local = _getLocalPosition(details.globalPosition);

_emitCursor(local, collab);

// The selection only makes sense while the Select tool is active.
if (tool != CanvasTool.select && _selectedObjectId != null) {
setState(() {
_selectedObjectId = null;
});
}

if (tool == CanvasTool.select) {
_selectObjectAt(local, collab);
} else if (tool == CanvasTool.text) {
_addTextAt(local, collab);
} else if (tool == CanvasTool.sticky) {
_addStickyNoteAt(local, collab);
} else if (tool == CanvasTool.eraser) {
collab.removeObjectNear(local, 20.0);
}
}

/// Sends this device's pointer to the other people on the board.
/// Throttled: at most one event every 50 ms.
void _emitCursor(Offset local, CollaborationProvider collab) {
final now = DateTime.now();

if (now.difference(_lastCursorSent).inMilliseconds < 50) return;

_lastCursorSent = now;
collab.sendCursor(local);
}

/// Topmost object under [point], or null when the point is empty canvas.
/// Later objects are painted on top, so search backwards.
CanvasObject? _topmostObjectAt(
Offset point,
CollaborationProvider collab,
) {
final objects = collab.objects;

for (var i = objects.length - 1; i >= 0; i--) {
final object = objects[i];

if (object.id == null) continue;

if (object.bounds.inflate(6).contains(point) ||
object.isNear(point, 12)) {
return object;
}
}

return null;
}

/// Picks the topmost object under [point], or clears the selection.
void _selectObjectAt(Offset point, CollaborationProvider collab) {
final object = _topmostObjectAt(point, collab);

setState(() {
_selectedObjectId = object?.id;
});
}

/// Starts a drag: on the selected object, or on whatever is under the
/// finger (which then becomes the selection).
void _beginDragSelected(Offset point, CollaborationProvider collab) {
final selectedId = _selectedObjectId;
final selected =
selectedId == null ? null : collab.objectById(selectedId);

if (selected != null && selected.bounds.inflate(8).contains(point)) {
setState(() {
_dragOrigin = point;
_dragSource = selected;
_dragPreview = selected;
});
return;
}

final hit = _topmostObjectAt(point, collab);

setState(() {
_selectedObjectId = hit?.id;
_dragOrigin = hit == null ? null : point;
_dragSource = hit;
_dragPreview = hit;
});
}

/// Follows the finger. The canvas paints [_dragPreview] in place of the
/// saved object, so nothing is sent to the server until the drag ends.
void _updateDragSelected(Offset point) {
final origin = _dragOrigin;
final source = _dragSource;

if (origin == null || source == null) return;

setState(() {
_dragPreview = source.movedBy(point - origin);
});
}

Future<void> _endDragSelected(CollaborationProvider collab) async {
final preview = _dragPreview;
final source = _dragSource;

setState(() {
_dragOrigin = null;
_dragSource = null;
_dragPreview = null;
});

if (preview == null || source == null) return;

// A tap, not a move.
if (preview.bounds == source.bounds) return;

await collab.updateObject(preview);

if (!mounted) return;

final error = collab.errorMessage;
if (error != null) _showSnack(error);
}

Future<void> _deleteSelectedObject() async {
final id = _selectedObjectId;

if (id == null) return;

final collab = Provider.of<CollaborationProvider>(
context,
listen: false,
);

setState(() {
_selectedObjectId = null;
});

await collab.removeObjectById(id);

if (!mounted) return;

final error = collab.errorMessage;
if (error != null) _showSnack(error);
}

void _handlePanStart(
DragStartDetails details,
CollaborationProvider collab,
) {
final tool = collab.selectedTool;

if (tool == CanvasTool.hand) {
return;
}

final local = _getLocalPosition(details.globalPosition);

_emitCursor(local, collab);

if (tool == CanvasTool.select) {
_beginDragSelected(local, collab);
return;
}

if (tool == CanvasTool.pen) {
_currentPath = [local];
} else if (tool == CanvasTool.eraser) {
collab.removeObjectNear(local, 20.0);
} else if (tool == CanvasTool.text || tool == CanvasTool.sticky) {
// The pan recogniser wins the arena as soon as the finger moves, so a
// tap that wobbles never reaches onTapDown. Remember where it started
// and let _handlePanEnd decide whether it was really a tap.
_startPoint = local;
_panTravel = 0;
} else {
_startPoint = local;
_currentPath = [local];
}
}

void _handlePanUpdate(
DragUpdateDetails details,
CollaborationProvider collab,
) {
final tool = collab.selectedTool;

if (tool == CanvasTool.hand) {
return;
}

final local = _getLocalPosition(details.globalPosition);

if (tool == CanvasTool.text || tool == CanvasTool.sticky) {
final start = _startPoint;

if (start != null) {
final travelled = (local - start).distance;
if (travelled > _panTravel) _panTravel = travelled;
}

return;
}

_emitCursor(local, collab);

if (tool == CanvasTool.select) {
_updateDragSelected(local);
return;
}

if (tool == CanvasTool.pen) {
setState(() {
_currentPath.add(local);
});
} else if (tool == CanvasTool.eraser) {
collab.removeObjectNear(local, 20.0);
} else if (tool == CanvasTool.rectangle ||
tool == CanvasTool.circle ||
tool == CanvasTool.triangle ||
tool == CanvasTool.diamond ||
tool == CanvasTool.arrow ||
tool == CanvasTool.connector) {
setState(() {
_currentPath.add(local);
});
}
}

void _handlePanEnd(
DragEndDetails details,
CollaborationProvider collab,
) {
final tool = collab.selectedTool;

if (tool == CanvasTool.hand) {
return;
}

if (tool == CanvasTool.select) {
_endDragSelected(collab);
return;
}

if (tool == CanvasTool.text || tool == CanvasTool.sticky) {
final start = _startPoint;
final travelled = _panTravel;

_startPoint = null;
_panTravel = 0;

// 18 logical pixels is the standard touch slop: anything shorter is a
// tap, not a drag.
if (start != null && travelled <= 18.0) {
if (tool == CanvasTool.text) {
_addTextAt(start, collab);
} else {
_addStickyNoteAt(start, collab);
}
}

return;
}

if (tool == CanvasTool.eraser) {
return;
}

if (tool == CanvasTool.pen) {
if (_currentPath.length > 1) {
collab.addObject(
PathObject(
points: List<Offset>.from(_currentPath),
color: collab.selectedColor,
thickness: collab.penThickness,
),
);

_markSaving();
}
} else if (_startPoint != null && _currentPath.isNotEmpty) {
final end = _currentPath.last;

if (tool == CanvasTool.rectangle) {
collab.addObject(
RectObject(
start: _startPoint!,
end: end,
color: collab.selectedColor,
thickness: collab.penThickness,
),
);
} else if (tool == CanvasTool.circle) {
collab.addObject(
CircleObject(
center: _startPoint!,
edge: end,
color: collab.selectedColor,
thickness: collab.penThickness,
),
);
} else if (tool == CanvasTool.triangle) {
collab.addObject(
TriangleObject(
start: _startPoint!,
end: end,
color: collab.selectedColor,
thickness: collab.penThickness,
),
);
} else if (tool == CanvasTool.diamond) {
collab.addObject(
DiamondObject(
start: _startPoint!,
end: end,
color: collab.selectedColor,
thickness: collab.penThickness,
),
);
} else if (tool == CanvasTool.arrow) {
collab.addObject(
ArrowObject(
start: _startPoint!,
end: end,
color: collab.selectedColor,
thickness: collab.penThickness,
),
);
} else if (tool == CanvasTool.connector) {
collab.addObject(
LineObject(
start: _startPoint!,
end: end,
color: collab.selectedColor,
thickness: collab.penThickness,
),
);
}

_markSaving();
}

if (!mounted) return;

setState(() {
_startPoint = null;
_currentPath = [];
});
}

// TEXT TOOL
Future<void> _addTextAt(
Offset position,
CollaborationProvider collab,
) async {
final text = await _promptForText(
title: 'Add Text Box',
hint: 'Enter text here...',
maxLines: 3,
);

if (!mounted || text == null) return;

final trimmed = text.trim();

if (trimmed.isEmpty) {
_showSnack('No text entered, so nothing was added.');
return;
}

await collab.addObject(
TextObject(
position: position,
text: trimmed,
color: collab.selectedColor,
),
);

if (!mounted) return;

debugPrint(
'addObject(text): objects=${collab.objects.length} '
'error=${collab.errorMessage}',
);

final error = collab.errorMessage;
if (error != null) _showSnack(error);

_markSaving();

// The provider calls notifyListeners(), but rebuild this canvas too so
// the new object is painted even if the notification is missed.
setState(() {});
}

// STICKY NOTE TOOL
Future<void> _addStickyNoteAt(
Offset position,
CollaborationProvider collab,
) async {
final text = await _promptForText(
title: 'Add Sticky Note',
hint: 'Write a note...',
maxLines: 4,
);

if (!mounted || text == null) return;

final trimmed = text.trim();

if (trimmed.isEmpty) {
_showSnack('No text entered, so nothing was added.');
return;
}

await collab.addObject(
StickyNoteObject(
position: position,
text: trimmed,
color: const Color(0xFFFEF08A),
),
);

if (!mounted) return;

debugPrint(
'addObject(sticky): objects=${collab.objects.length} '
'error=${collab.errorMessage}',
);

final error = collab.errorMessage;
if (error != null) _showSnack(error);

_markSaving();

setState(() {});
}

Future<String?> _promptForText({
required String title,
required String hint,
required int maxLines,
}) {
return showDialog<String>(
context: context,
builder: (_) => _TextInputDialog(
title: title,
hint: hint,
maxLines: maxLines,
),
);
}

void _showSnack(String message) {
if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text(message)),
);
}

/// Creates (or reuses) the board's read-only share token and shows it.
Future<void> _openShareLink(CollaborationProvider collab) async {
_showSnack('Creating a share link...');

final token = await collab.createShareLink();

if (!mounted) return;

if (token == null) {
_showSnack(collab.errorMessage ?? 'Could not create a share link.');
return;
}

// /api is the API prefix, not part of the public link.
final base =
ApiService.currentBaseUrl.replaceAll(RegExp(r'/api/?$'), '');
final link = '$base/share/$token';

await showDialog<void>(
context: context,
builder: (dialogContext) => AlertDialog(
title: const Text('Share link'),
content: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
'Anyone with this link can view the board without '
'signing in. They cannot change anything.',
),
const SizedBox(height: 12),
SelectableText(
link,
style: const TextStyle(fontSize: 12),
),
],
),
actions: [
TextButton(
onPressed: () => Navigator.pop(dialogContext),
child: const Text('Close'),
),
ElevatedButton.icon(
onPressed: () async {
await Clipboard.setData(ClipboardData(text: link));

if (dialogContext.mounted) {
Navigator.pop(dialogContext);
}
},
icon: const Icon(Icons.copy, size: 18),
label: const Text('Copy'),
),
],
),
);
}

/// Renders the whole board to a PNG and hands it to the share sheet.
Future<void> _exportBoardPng(CollaborationProvider collab) async {
if (collab.objects.isEmpty) {
_showSnack('Nothing to export yet - draw something first.');
return;
}

_showSnack('Rendering the board...');

final bytes = await BoardExporter.toPng(collab.objects);

if (!mounted) return;

if (bytes == null) {
_showSnack('Could not render the board.');
return;
}

final file = XFile.fromData(
bytes,
mimeType: 'image/png',
name: 'board_${widget.board.id}.png',
);

await Share.shareXFiles(
  [file],
  text: widget.board.title,
  subject: widget.board.title,
);

}

void _showAiAssistant() {
showDialog(
context: context,
builder: (c) => AlertDialog(
title: const Row(
children: [
Icon(
Icons.auto_awesome,
color: Color(0xFF5B4BDB),
),
SizedBox(width: 8),
Text('CollabBoard AI Assistant'),
],
),
content: const Text(
'AI Assistant is ready to help you brainstorm ideas, '
'summarize sticky notes, generate flowcharts, and answer '
'questions about your board workspace.',
),
actions: [
ElevatedButton(
onPressed: () => Navigator.pop(c),
child: const Text('Got it'),
),
],
),
);
}

void _showPresentationMode() {
showDialog(
context: context,
builder: (c) => AlertDialog(
title: const Text('Presentation Mode'),
content: const Text(
'Entering fullscreen presentation view. '
'Press Close to return to the editor.',
),
actions: [
TextButton(
onPressed: () => Navigator.pop(c),
child: const Text('Close'),
),
],
),
);
}

void _showThreeDotMenu(CollaborationProvider collab) {
showModalBottomSheet(
context: context,
shape: const RoundedRectangleBorder(
borderRadius: BorderRadius.vertical(
top: Radius.circular(20),
),
),
builder: (c) => Container(
padding: const EdgeInsets.all(20),
child: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.stretch,
children: [
const Text(
'Canvas Options',
style: TextStyle(
fontSize: 18,
fontWeight: FontWeight.bold,
),
textAlign: TextAlign.center,
),
const Divider(height: 24),
ListTile(
leading: const Icon(
Icons.auto_awesome,
color: Color(0xFF5B4BDB),
),
title: const Text('AI Assistant'),
onTap: () {
Navigator.pop(c);
_showAiAssistant();
},
),
ListTile(
leading: const Icon(
Icons.slideshow_outlined,
color: Color(0xFF5B4BDB),
),
title: const Text('Presentation Mode'),
onTap: () {
Navigator.pop(c);
_showPresentationMode();
},
),
ListTile(
leading: const Icon(
Icons.share,
color: Color(0xFF5B4BDB),
),
title: const Text('Share Board'),
onTap: () {
Navigator.pop(c);
_openShareDialog();
},
),
ListTile(
leading: const Icon(
Icons.link,
color: Color(0xFF5B4BDB),
),
title: const Text('Share link'),
subtitle: const Text('Read-only link, no sign-in needed'),
onTap: () {
Navigator.pop(c);
_openShareLink(collab);
},
),
ListTile(
leading: const Icon(
Icons.grid_on,
color: Color(0xFF5B4BDB),
),
title: Text(
collab.showGrid ? 'Hide Grid' : 'Show Grid',
),
onTap: () {
Navigator.pop(c);
collab.toggleGrid();
},
),
ListTile(
leading: const Icon(
Icons.undo,
color: Color(0xFF5B4BDB),
),
title: const Text('Undo'),
onTap: collab.canUndo
? () {
Navigator.pop(c);
collab.undo();
}
: null,
),
ListTile(
leading: const Icon(
Icons.redo,
color: Color(0xFF5B4BDB),
),
title: const Text('Redo'),
onTap: collab.canRedo
? () {
Navigator.pop(c);
collab.redo();
}
: null,
),
ListTile(
leading: const Icon(
Icons.image_outlined,
color: Colors.green,
),
title: const Text('Export as PNG'),
subtitle: const Text('Save or share an image of the board'),
onTap: () {
Navigator.pop(c);
_exportBoardPng(collab);
},
),
ListTile(
leading: const Icon(
Icons.delete_sweep,
color: Colors.red,
),
title: const Text('Clear Canvas'),
onTap: () async {
Navigator.pop(c);

final confirm = await showDialog<bool>(
context: context,
builder: (dialogContext) => AlertDialog(
title: const Text('Clear Canvas'),
content: const Text(
'Are you sure you want to delete all objects '
'from this board? This action cannot be undone.',
),
actions: [
TextButton(
onPressed: () =>
Navigator.pop(dialogContext, false),
child: const Text('Cancel'),
),
ElevatedButton(
style: ElevatedButton.styleFrom(
backgroundColor: Colors.red,
),
onPressed: () =>
Navigator.pop(dialogContext, true),
child: const Text('Clear All'),
),
],
),
);

if (confirm == true && mounted) {
// Delete by id: exact, and never touches a neighbour.
final ids = collab.objects
.map((object) => object.id)
.whereType<int>()
.toList();

for (final id in ids) {
await collab.removeObjectById(id);
}

if (mounted) {
setState(() {});
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Canvas cleared.'),
),
);
}
}
},
),
],
),
),
);
}

Future<void> _leaveBoard() async {
final confirm = await showDialog<bool>(
context: context,
builder: (c) => AlertDialog(
title: const Text('Leave Board'),
content: const Text(
'Are you sure you want to exit this workspace?',
),
actions: [
TextButton(
onPressed: () => Navigator.pop(c, false),
child: const Text('Cancel'),
),
ElevatedButton(
onPressed: () => Navigator.pop(c, true),
child: const Text('Leave'),
),
],
),
);

if (confirm == true && mounted) {
Provider.of<CollaborationProvider>(
context,
listen: false,
).leaveBoard();

Navigator.of(context).pop();
}
}

void _openShareDialog() {
showDialog(
context: context,
builder: (c) => ShareDialog(board: widget.board),
);
}

@override
Widget build(BuildContext context) {
final theme = Theme.of(context);
final screenWidth = MediaQuery.of(context).size.width;

return Consumer<CollaborationProvider>(
builder: (context, collab, _) {
final isHandTool =
collab.selectedTool == CanvasTool.hand;

// While dragging, paint the moved copy in place of the saved object.
final dragPreview = _dragPreview;
final List<CanvasObject> painterObjects;

if (dragPreview == null) {
painterObjects = collab.objects;
} else {
painterObjects = collab.objects
.map<CanvasObject>(
(object) =>
object.id == dragPreview.id ? dragPreview : object,
)
.toList();
}

return Scaffold(
appBar: AppBar(
elevation: 1,
backgroundColor:
theme.appBarTheme.backgroundColor ??
theme.colorScheme.surface,
title: Row(
children: [
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
mainAxisSize: MainAxisSize.min,
children: [
Text(
widget.board.title,
maxLines: 1,
overflow: TextOverflow.ellipsis,
style: TextStyle(
fontSize: 16,
fontWeight: FontWeight.bold,
color: theme.colorScheme.onSurface,
),
),
Row(
children: [
Container(
width: 7,
height: 7,
decoration: BoxDecoration(
color: _isSavingStatus
? Colors.orange
: Colors.green,
shape: BoxShape.circle,
),
),
const SizedBox(width: 5),
Expanded(
child: Text(
_isSavingStatus
? 'Saving changes...'
: 'Saved to Cloud â€¢ '
'${collab.activeUsers.length} online',
maxLines: 1,
overflow: TextOverflow.ellipsis,
style: TextStyle(
fontSize: 11,
color:
theme.colorScheme.onSurfaceVariant,
),
),
),
],
),
],
),
),
],
),
actions: [
if (screenWidth > 500 &&
collab.activeUsers.isNotEmpty)
Padding(
padding: const EdgeInsets.only(right: 8),
child: Row(
children:
collab.activeUsers.take(3).map((u) {
return Padding(
padding: const EdgeInsets.symmetric(
horizontal: 2,
),
child: CircleAvatar(
radius: 14,
backgroundColor:
const Color(0xFF5B4BDB),
child: Text(
u.name.isNotEmpty
? u.name[0].toUpperCase()
: 'U',
style: const TextStyle(
fontSize: 11,
color: Colors.white,
fontWeight: FontWeight.bold,
),
),
),
);
}).toList(),
),
),
if (screenWidth > 600) ...[
IconButton(
icon: const Icon(
Icons.auto_awesome,
color: Color(0xFF5B4BDB),
),
tooltip: 'AI Assistant',
onPressed: _showAiAssistant,
),
IconButton(
icon: Icon(
Icons.slideshow_outlined,
color: theme.colorScheme.onSurface,
),
tooltip: 'Present',
onPressed: _showPresentationMode,
),
],
IconButton(
icon: Icon(
Icons.undo,
color: theme.colorScheme.onSurface,
),
tooltip: 'Undo',
onPressed: collab.canUndo ? collab.undo : null,
),
IconButton(
icon: Icon(
Icons.redo,
color: theme.colorScheme.onSurface,
),
tooltip: 'Redo',
onPressed: collab.canRedo ? collab.redo : null,
),
if (screenWidth > 450)
IconButton(
icon: Icon(
Icons.share,
color: theme.colorScheme.onSurface,
),
tooltip: 'Share Board',
onPressed: _openShareDialog,
),
IconButton(
icon: Icon(
Icons.more_vert,
color: theme.colorScheme.onSurface,
),
tooltip: 'More Options',
onPressed: () => _showThreeDotMenu(collab),
),
IconButton(
icon: Icon(
Icons.exit_to_app,
color: theme.colorScheme.onSurface,
),
tooltip: 'Leave Workspace',
onPressed: _leaveBoard,
),
],
),

body: Stack(
children: [
Column(
children: [
if (collab.isLoading)
const LinearProgressIndicator(
color: Color(0xFF5B4BDB),
),

Expanded(
child: LayoutBuilder(
builder: (context, constraints) {
// Remember the visible area so zooming stays centred.
_viewportSize = constraints.biggest;

return InteractiveViewer(
transformationController:
_transformationController,
panEnabled: isHandTool,
scaleEnabled: true,
minScale: 0.25,
maxScale: 3.0,

// The child is larger than the viewport, so it must
// not be constrained to the viewport size.
constrained: false,

// A little slack so you can pan past the edges.
boundaryMargin:
const EdgeInsets.all(400),
child: GestureDetector(
key: _canvasKey,
behavior: HitTestBehavior.opaque,
onTapDown: (details) =>
_handleCanvasTap(details, collab),
onPanStart: (details) =>
_handlePanStart(details, collab),
onPanUpdate: (details) =>
_handlePanUpdate(details, collab),
onPanEnd: (details) =>
_handlePanEnd(details, collab),
child: SizedBox(
width: _canvasSize.width,
height: _canvasSize.height,
child: CustomPaint(
size: _canvasSize,
painter: WhiteboardPainter(
objects: painterObjects,
currentPath: _currentPath,
penColor: collab.selectedColor,
penThickness:
collab.penThickness,
showGrid: collab.showGrid,
selectedObjectId:
_selectedObjectId,
cursors: collab.cursors,
),
),
),
),
);
},
),
),

// BOTTOM ZOOM TOOLBAR
Container(
color: theme.cardTheme.color ??
theme.colorScheme.surface,
padding: const EdgeInsets.symmetric(
horizontal: 8,
vertical: 4,
),
child: Wrap(
alignment: WrapAlignment.center,
crossAxisAlignment: WrapCrossAlignment.center,
spacing: 4,
children: [
IconButton(
constraints: const BoxConstraints(
minWidth: 32,
minHeight: 32,
),
padding: EdgeInsets.zero,
icon: const Icon(
Icons.zoom_out,
size: 18,
),
onPressed: _zoomOut,
tooltip: 'Zoom Out',
),
Text(
'${(_currentScale * 100).toInt()}%',
style: const TextStyle(
fontWeight: FontWeight.bold,
fontSize: 12,
),
),
IconButton(
constraints: const BoxConstraints(
minWidth: 32,
minHeight: 32,
),
padding: EdgeInsets.zero,
icon: const Icon(
Icons.zoom_in,
size: 18,
),
onPressed: _zoomIn,
tooltip: 'Zoom In',
),
IconButton(
constraints: const BoxConstraints(
minWidth: 32,
minHeight: 32,
),
padding: EdgeInsets.zero,
icon: Icon(
collab.showGrid
? Icons.grid_on
: Icons.grid_off,
size: 18,
),
tooltip: 'Toggle Grid',
onPressed: collab.toggleGrid,
),
],
),
),
],
),

// LEFT DRAWING TOOLBAR
Positioned(
left: 12,
top: 12,
child: Container(
padding: const EdgeInsets.all(6),
decoration: BoxDecoration(
color: theme.cardTheme.color ??
theme.colorScheme.surface,
borderRadius: BorderRadius.circular(16),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: 0.08),
blurRadius: 10,
offset: const Offset(0, 4),
),
],
border: Border.all(
color: theme.dividerTheme.color ??
const Color(0xFFE9E9F2),
),
),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
_buildToolButton(
icon: Icons.near_me_outlined,
tool: CanvasTool.select,
collab: collab,
tooltip: 'Select',
),
_buildToolButton(
icon: Icons.pan_tool_outlined,
tool: CanvasTool.hand,
collab: collab,
tooltip: 'Hand / Pan',
),
_buildToolButton(
icon: Icons.edit_outlined,
tool: CanvasTool.pen,
collab: collab,
tooltip: 'Pen',
),
_buildToolButton(
icon: Icons.cleaning_services_outlined,
tool: CanvasTool.eraser,
collab: collab,
tooltip: 'Eraser',
),

// Select Text, then tap the canvas.
_buildToolButton(
icon: Icons.text_fields,
tool: CanvasTool.text,
collab: collab,
tooltip: 'Text - Select and tap canvas',
),

// Select Sticky Note, then tap the canvas.
_buildToolButton(
icon: Icons.sticky_note_2_outlined,
tool: CanvasTool.sticky,
collab: collab,
tooltip:
'Sticky Note - Select and tap canvas',
),

_buildToolButton(
icon: Icons.crop_square,
tool: CanvasTool.rectangle,
collab: collab,
tooltip: 'Rectangle',
),
_buildToolButton(
icon: Icons.circle_outlined,
tool: CanvasTool.circle,
collab: collab,
tooltip: 'Circle',
),
_buildToolButton(
icon: Icons.change_history,
tool: CanvasTool.triangle,
collab: collab,
tooltip: 'Triangle',
),
_buildToolButton(
icon: Icons.diamond_outlined,
tool: CanvasTool.diamond,
collab: collab,
tooltip: 'Diamond',
),
_buildToolButton(
icon: Icons.arrow_forward,
tool: CanvasTool.arrow,
collab: collab,
tooltip: 'Arrow',
),
_buildToolButton(
icon: Icons.linear_scale,
tool: CanvasTool.connector,
collab: collab,
tooltip: 'Connector Line',
),
],
),
),
),

// RIGHT PROPERTIES PANEL
if (_showPropertiesPanel)
Positioned(
right: 12,
top: 12,
child: Container(
width: screenWidth > 400
? 220
: screenWidth - 40,
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: theme.cardTheme.color ??
theme.colorScheme.surface,
borderRadius: BorderRadius.circular(16),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: 0.1),
blurRadius: 12,
offset: const Offset(0, 4),
),
],
border: Border.all(
color: theme.dividerTheme.color ??
const Color(0xFFE9E9F2),
),
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
mainAxisSize: MainAxisSize.min,
children: [
Row(
children: [
const Expanded(
child: Text(
'Properties',
style: TextStyle(
fontWeight: FontWeight.bold,
fontSize: 14,
),
),
),
IconButton(
constraints: const BoxConstraints(
minWidth: 28,
minHeight: 28,
),
padding: EdgeInsets.zero,
icon: const Icon(
Icons.close,
size: 18,
),
onPressed: () {
setState(() {
_showPropertiesPanel = false;
});
},
),
],
),
const Divider(height: 12),
const Text(
'Color Palette',
style: TextStyle(
fontSize: 12,
color: Colors.grey,
),
),
const SizedBox(height: 8),
Wrap(
spacing: 8,
runSpacing: 8,
children: [
const Color(0xFF5B4BDB),
Colors.black,
Colors.red,
Colors.green,
Colors.blue,
Colors.orange,
Colors.purple,
Colors.amber,
].map((color) {
final isSelected =
collab.selectedColor == color;

return GestureDetector(
onTap: () => collab.setColor(color),
child: Container(
width: 28,
height: 28,
decoration: BoxDecoration(
color: color,
shape: BoxShape.circle,
border: Border.all(
color: isSelected
? Colors.white
: Colors.transparent,
width: 2.5,
),
boxShadow: isSelected
? [
const BoxShadow(
color: Colors.black38,
blurRadius: 4,
),
]
: null,
),
),
);
}).toList(),
),
const SizedBox(height: 16),
const Text(
'Stroke Thickness',
style: TextStyle(
fontSize: 12,
color: Colors.grey,
),
),
Slider(
min: 1,
max: 12,
value: collab.penThickness,
activeColor: const Color(0xFF5B4BDB),
onChanged: collab.setThickness,
),
const SizedBox(height: 8),
Text(
'Objects on Canvas: ${collab.objects.length}',
style: const TextStyle(
fontSize: 12,
fontWeight: FontWeight.w500,
),
),
],
),
),
),

// DELETE SELECTED OBJECT
if (_selectedObjectId != null)
Positioned(
right: 12,
bottom: 72,
child: FloatingActionButton.small(
heroTag: 'delete-selected',
backgroundColor: Colors.red,
tooltip: 'Delete selected object',
onPressed: _deleteSelectedObject,
child: const Icon(
Icons.delete_outline,
color: Colors.white,
),
),
),
],
),

floatingActionButton: !_showPropertiesPanel
? FloatingActionButton.small(
  backgroundColor: const Color(0xFF5B4BDB),
  child: const Icon(
    Icons.palette_outlined,
    color: Colors.white,
  ),
  onPressed: () {
    setState(() {
      _showPropertiesPanel = true;
    });
  },
)
    : null,
);
},
);
}

  Widget _buildToolButton({
    required IconData icon,
    required CanvasTool tool,
    required CollaborationProvider collab,
    required String tooltip,
    VoidCallback? onPressed,
  }) {
    final theme = Theme.of(context);
    final isSelected = collab.selectedTool == tool;

    return IconButton(
      icon: Icon(
        icon,
        size: 22,
        color: isSelected
            ? const Color(0xFF5B4BDB)
            : theme.colorScheme.onSurface,
      ),
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: isSelected
            ? const Color(0xFF5B4BDB).withValues(alpha: 0.15)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      onPressed: onPressed ?? () => collab.setTool(tool),
    );
  }
}

/// Owns its own [TextEditingController] so the controller outlives the
/// dialog's exit animation. Disposing a controller straight after
/// `showDialog` returns throws "used after being disposed".
class _TextInputDialog extends StatefulWidget {
  final String title;
  final String hint;
  final int maxLines;

  const _TextInputDialog({
    required this.title,
    required this.hint,
    this.maxLines = 3,
  });

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: widget.maxLines,
        decoration: InputDecoration(hintText: widget.hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

