export const errorResponse = (res, status, message) => {
    return res.status(status).json({ error: message });
};
export const unauthorized = (res, message = 'Unauthorized') => errorResponse(res, 401, message);
export const forbidden = (res, message = 'Forbidden') => errorResponse(res, 403, message);
export const badRequest = (res, message) => errorResponse(res, 400, message);
export const serverError = (res, message = 'Internal server error') => errorResponse(res, 500, message);
export const successResponse = (res, data) => {
    return res.json(data);
};
//# sourceMappingURL=responses.js.map