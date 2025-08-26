#class_name GnumarusSceneTreeViewButtonsTreeItemHelper
@tool
extends TreeItem
signal predelete



func _notification(p_what: int) -> void:
	if p_what == NOTIFICATION_PREDELETE:
		print('TreeItem is about to be deleted')
		predelete.emit()
