// Helpers for dismissing Quickshell notifications safely.
//
// Quickshell's ObjectModel `values` (NotificationServer.trackedNotifications
// .values, Bluetooth.devices.values, ...) is a LIVE view of the backing list,
// not a snapshot. Notification.dismiss() removes the entry synchronously, so a
// forward loop over `values` shifts the next entry into the current index and
// skips every other one. Snapshot the ids first, then dismiss by id.

function snapshotIds(values) {
  const ids = []
  if (!values) return ids
  for (let i = 0; i < values.length; i++) ids.push(values[i].id)
  return ids
}

// Dismiss every notification in `values`. Returns the ids that were dismissed.
// `dismiss(id)` must remove the notification from the underlying live model.
export function dismissAll(values, dismiss) {
  const ids = snapshotIds(values)
  for (let i = 0; i < ids.length; i++) dismiss(ids[i])
  return ids
}

// Dismiss every notification matching `predicate`. Returns the matched ids.
// Predicates are evaluated against the pre-dismissal snapshot.
export function dismissWhere(values, predicate, dismiss) {
  const ids = []
  if (values) {
    for (let i = 0; i < values.length; i++) {
      const value = values[i]
      if (predicate(value)) ids.push(value.id)
    }
  }
  for (let i = 0; i < ids.length; i++) dismiss(ids[i])
  return ids
}
