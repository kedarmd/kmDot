import test from "node:test";
import assert from "node:assert/strict";

import {
  dismissAll,
  dismissWhere,
} from "../../config/quickshell/components/notificationlive.mjs";

// Faithful fake of Quickshell's ObjectModel `values`: the array the caller
// holds is live, and dismissing removes the entry from that same array.
function liveModel(entries) {
  const values = entries.map((entry) => ({ ...entry }));
  const dismissed = [];
  return {
    values,
    dismissed,
    dismiss(id) {
      dismissed.push(id);
      const index = values.findIndex((value) => value.id === id);
      if (index >= 0) values.splice(index, 1);
    },
  };
}

const six = [
  { id: 1, appName: "alpha" },
  { id: 2, appName: "alpha" },
  { id: 3, appName: "beta" },
  { id: 4, appName: "alpha" },
  { id: 5, appName: "beta" },
  { id: 6, appName: "alpha" },
];

test("fake is faithful: a naive forward loop over the live view skips entries", () => {
  const model = liveModel(six);
  for (let i = 0; i < model.values.length; i++) model.dismiss(model.values[i].id);

  // The regression this file exists for: 6 notifications, only 3 dismissed.
  assert.deepEqual(model.dismissed, [1, 3, 5]);
  assert.deepEqual(model.values.map((value) => value.id), [2, 4, 6]);
});

test("dismissAll dismisses every notification when the live view shrinks", () => {
  const model = liveModel(six);
  const ids = dismissAll(model.values, (id) => model.dismiss(id));

  assert.deepEqual(ids, [1, 2, 3, 4, 5, 6]);
  assert.deepEqual(model.dismissed, [1, 2, 3, 4, 5, 6]);
  assert.equal(model.values.length, 0);
});

test("dismissWhere dismisses every match, evaluated against the snapshot", () => {
  const model = liveModel(six);
  const ids = dismissWhere(
    model.values,
    (value) => value.appName === "alpha",
    (id) => model.dismiss(id),
  );

  assert.deepEqual(ids, [1, 2, 4, 6]);
  assert.deepEqual(model.dismissed, [1, 2, 4, 6]);
  assert.deepEqual(model.values.map((value) => value.id), [3, 5]);
});

test("helpers tolerate a missing model", () => {
  let calls = 0;
  assert.deepEqual(dismissAll(undefined, () => calls++), []);
  assert.deepEqual(dismissWhere(null, () => true, () => calls++), []);
  assert.equal(calls, 0);
});
