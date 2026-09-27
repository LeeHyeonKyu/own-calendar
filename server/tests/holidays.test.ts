/**
 * Integration tests for holiday route validation (issue #46).
 *
 * Proves that POST /subscribe rejects malformed countryCode with 400
 * and GET /holidays rejects missing or out-of-range year with 400,
 * instead of passing them unchecked to the service layer.
 */
import request from 'supertest';
import { vi } from 'vitest';
import app from '../src/app';
import { createTestUser, prisma } from './setup';
import { holidayService } from '../src/services/holiday.service';

describe('test_46_holidays_validation', () => {
  // Clean up HolidaySubscription and Holiday tables (not covered by setup.ts beforeEach)
  beforeEach(async () => {
    await prisma.holiday.deleteMany();
    await prisma.holidaySubscription.deleteMany();
  });

  describe('test_46_subscribe_invalid_country', () => {
    it('rejects lower-case countryCode with 400', async () => {
      const user = await createTestUser(app);

      const res = await request(app)
        .post('/api/holidays/subscribe')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ countryCode: 'kr' });

      expect(res.status).toBe(400);
      expect(res.body).toHaveProperty('error');
    });

    it('rejects 3-letter countryCode with 400', async () => {
      const user = await createTestUser(app);

      const res = await request(app)
        .post('/api/holidays/subscribe')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ countryCode: 'KOR' });

      expect(res.status).toBe(400);
      expect(res.body).toHaveProperty('error');
    });

    it('rejects missing countryCode with 400', async () => {
      const user = await createTestUser(app);

      const res = await request(app)
        .post('/api/holidays/subscribe')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({});

      expect(res.status).toBe(400);
      expect(res.body).toHaveProperty('error');
    });
  });

  describe('test_46_get_holidays_missing_year', () => {
    it('rejects request without year query parameter with 400', async () => {
      const user = await createTestUser(app);

      const res = await request(app)
        .get('/api/holidays/holidays')
        .set('Authorization', `Bearer ${user.accessToken}`);

      expect(res.status).toBe(400);
      expect(res.body).toHaveProperty('error');
    });
  });

  describe('test_46_get_holidays_out_of_range_year', () => {
    it('rejects year=0 with 400', async () => {
      const user = await createTestUser(app);

      const res = await request(app)
        .get('/api/holidays/holidays?year=0')
        .set('Authorization', `Bearer ${user.accessToken}`);

      expect(res.status).toBe(400);
      expect(res.body).toHaveProperty('error');
    });

    it('rejects year=3000 with 400', async () => {
      const user = await createTestUser(app);

      const res = await request(app)
        .get('/api/holidays/holidays?year=3000')
        .set('Authorization', `Bearer ${user.accessToken}`);

      expect(res.status).toBe(400);
      expect(res.body).toHaveProperty('error');
    });
  });

  describe('test_46_happy_paths', () => {
    beforeEach(() => {
      // Mock refreshHolidays to avoid external HTTP calls (dissent-2)
      vi.spyOn(holidayService, 'refreshHolidays').mockResolvedValue(undefined);
    });

    afterEach(() => {
      vi.restoreAllMocks();
    });

    it('POST /subscribe with valid 2-letter upper-case countryCode returns 200', async () => {
      const user = await createTestUser(app);

      const res = await request(app)
        .post('/api/holidays/subscribe')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ countryCode: 'US' });

      expect([200, 201]).toContain(res.status);
      expect(res.body).toHaveProperty('countryCode', 'US');
      expect(res.body).toHaveProperty('userId');
    });

    it('GET /holidays with valid year returns 200 and an array', async () => {
      const user = await createTestUser(app);

      const res = await request(app)
        .get('/api/holidays/holidays?year=2025')
        .set('Authorization', `Bearer ${user.accessToken}`);

      expect(res.status).toBe(200);
      expect(Array.isArray(res.body)).toBe(true);
    });

    it('GET /holidays with valid year and month returns 200 and an array', async () => {
      const user = await createTestUser(app);

      const res = await request(app)
        .get('/api/holidays/holidays?year=2025&month=6')
        .set('Authorization', `Bearer ${user.accessToken}`);

      expect(res.status).toBe(200);
      expect(Array.isArray(res.body)).toBe(true);
    });
  });
});
