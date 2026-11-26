const assert = require("node:assert/strict");
const test = require("node:test");

const { canBookAsPatient } = require("../lib/booking-policy.js");

test("legacy signed-in accounts without a role claim can book as patients", () => {
  assert.equal(canBookAsPatient(undefined), true);
});

test("users and admins can book for themselves", () => {
  assert.equal(canBookAsPatient("user"), true);
  assert.equal(canBookAsPatient("admin"), true);
});

test("other roles cannot book as patients", () => {
  assert.equal(canBookAsPatient("doctor"), false);
  assert.equal(canBookAsPatient(null), false);
  assert.equal(canBookAsPatient("unknown"), false);
});
