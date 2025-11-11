export const PERM = { C:1, R:2, U:4, D:8 };
export const has  = (mask:number, p:number) => (mask & p) === p;
