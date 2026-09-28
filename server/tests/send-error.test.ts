import { sendError } from '../src/lib/send-error';

describe('test_52_send_error_helper', () => {
  function mockResponse() {
    const res: any = {};
    res.status = vi.fn().mockReturnValue(res);
    res.json = vi.fn().mockReturnValue(res);
    return res;
  }

  it('test_52_status_code_honoured: uses err.statusCode when present', () => {
    const res = mockResponse();
    const err = { statusCode: 404, message: 'Not found' };

    sendError(res, err);

    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith({ error: 'Not found' });
  });

  it('test_52_default_500: defaults to 500 when statusCode is absent', () => {
    const res = mockResponse();
    const err = { message: 'Something broke' };

    sendError(res, err);

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({ error: 'Something broke' });
  });

  it('test_52_message_passthrough: passes err.message through verbatim', () => {
    const res = mockResponse();
    const err = { statusCode: 422, message: 'Validation failed: field "name" is required' };

    sendError(res, err);

    expect(res.status).toHaveBeenCalledWith(422);
    expect(res.json).toHaveBeenCalledWith({
      error: 'Validation failed: field "name" is required',
    });
  });

  it('test_52_zero_status_code: treats statusCode 0 as falsy and defaults to 500', () => {
    const res = mockResponse();
    const err = { statusCode: 0, message: 'Zero status' };

    sendError(res, err);

    // statusCode 0 is falsy, so || 500 should kick in — matches the inline pattern
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({ error: 'Zero status' });
  });
});
