export const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export const isValidUUID = (value) => {
    return UUID_REGEX.test(value);
};
export const isValidEmail = (email) => {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
};
export const isValidPassword = (password, minLength = 8) => {
    return typeof password === 'string' && password.length >= minLength;
};
export const isNonEmptyString = (value) => {
    return typeof value === 'string' && value.trim().length > 0;
};
//# sourceMappingURL=validation.js.map