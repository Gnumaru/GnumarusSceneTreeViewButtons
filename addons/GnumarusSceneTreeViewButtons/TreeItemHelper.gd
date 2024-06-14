#class_name GnumarusSceneTreeViewButtonsTreeItemHelper
extends TreeItem
signal predelete


func _notification(pwhat: int) -> void:
	if pwhat == NOTIFICATION_PREDELETE:
		predelete.emit()
