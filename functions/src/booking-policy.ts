export function canBookAsPatient(role: unknown): boolean {
  return role === undefined || role === "user" || role === "admin";
}
