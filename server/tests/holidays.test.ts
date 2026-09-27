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
      // app.ts globalLimiter sets legacyHeaders: false — legacy rate-limit headers must be absent
      expect(res.headers).not.toHaveProperty('x-ratelimit-limit');
      // Content-type must be JSON (relies on express.json() + res.json() chain through app.ts)
      expect(res.headers['content-type']).toMatch(/application\/json/);
      // Validation error body must include the specific error message and details from validate middleware
      expect(res.body.error).toBe('Validation failed');
      expect(res.body).toHaveProperty('details');
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
      expect(res.body.error).toBe('Validation failed');
      expect(res.body).toHaveProperty('details');
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
      // app.ts globalLimiter sets legacyHeaders: false — legacy rate-limit headers must be absent
      expect(res.headers).not.toHaveProperty('x-ratelimit-limit');
      expect(res.headers['content-type']).toMatch(/application\/json/);
      expect(res.body.error).toBe('Validation failed');
      expect(res.body).toHaveProperty('details');
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
      // app.ts globalLimiter sets legacyHeaders: false — legacy rate-limit headers must be absent
      expect(res.headers).not.toHaveProperty('x-ratelimit-limit');
      expect(res.headers['content-type']).toMatch(/application\/json/);
      expect(res.body.error).toBe('Validation failed');
      expect(res.body).toHaveProperty('details');
    });

    it('rejects year=3000 with 400', async () => {
      const user = await createTestUser(app);

      const res = await request(app)
        .get('/api/holidays/holidays?year=3000')
        .set('Authorization', `Bearer ${user.accessToken}`);

      expect(res.status).toBe(400);
      expect(res.body).toHaveProperty('error');
      expect(res.body.error).toBe('Validation failed');
      expect(res.body).toHaveProperty('details');
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
      // app.ts globalLimiter sets legacyHeaders: false — legacy rate-limit headers must be absent
      expect(res.headers).not.toHaveProperty('x-ratelimit-limit');
      expect(res.headers['content-type']).toMatch(/application\/json/);
    });

    it('GET /holidays with valid year returns 200 and an array', async () => {
      const user = await createTestUser(app);

      const res = await request(app)
        .get('/api/holidays/holidays?year=2025')
        .set('Authorization', `Bearer ${user.accessToken}`);

      expect(res.status).toBe(200);
      expect(Array.isArray(res.body)).toBe(true);
      // app.ts globalLimiter sets legacyHeaders: false — legacy rate-limit headers must be absent
      expect(res.headers).not.toHaveProperty('x-ratelimit-limit');
      expect(res.headers['content-type']).toMatch(/application\/json/);
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

  describe('test_46_get_holidays_country_filter', () => {
    beforeEach(() => {
      // Mock refreshHolidays to avoid external HTTP calls (dissent-2)
      vi.spyOn(holidayService, 'refreshHolidays').mockResolvedValue(undefined);
    });

    afterEach(() => {
      vi.restoreAllMocks();
    });

    it('GET /holidays?countryCode=US returns only US holidays when subscribed to US and KR', async () => {
      const user = await createTestUser(app);

      // Subscribe to both US and KR via API (refreshHolidays is mocked)
      await request(app)
        .post('/api/holidays/subscribe')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ countryCode: 'US' });
      await request(app)
        .post('/api/holidays/subscribe')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ countryCode: 'KR' });

      // Seed Holiday rows for both countries
      await prisma.holiday.create({
        data: { countryCode: 'US', date: new Date(2025, 6, 4), name: 'Independence Day', year: 2025 },
      });
      await prisma.holiday.create({
        data: { countryCode: 'KR', date: new Date(2025, 7, 15), name: 'Liberation Day', year: 2025 },
      });

      const res = await request(app)
        .get('/api/holidays/holidays?year=2025&countryCode=US')
        .set('Authorization', `Bearer ${user.accessToken}`);

      expect(res.status).toBe(200);
      expect(Array.isArray(res.body)).toBe(true);
      expect(res.body.length).toBe(1);
      // Every returned holiday must be for the requested country
      expect(res.body.every((h: any) => h.countryCode === 'US')).toBe(true);
      expect(res.body[0].name).toBe('Independence Day');
    });

    it('GET /holidays without countryCode returns holidays for all subscribed countries', async () => {
      const user = await createTestUser(app);

      // Subscribe to both US and KR via API (refreshHolidays is mocked)
      await request(app)
        .post('/api/holidays/subscribe')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ countryCode: 'US' });
      await request(app)
        .post('/api/holidays/subscribe')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ countryCode: 'KR' });

      // Seed Holiday rows for both countries
      await prisma.holiday.create({
        data: { countryCode: 'US', date: new Date(2025, 6, 4), name: 'Independence Day', year: 2025 },
      });
      await prisma.holiday.create({
        data: { countryCode: 'KR', date: new Date(2025, 7, 15), name: 'Liberation Day', year: 2025 },
      });

      const res = await request(app)
        .get('/api/holidays/holidays?year=2025')
        .set('Authorization', `Bearer ${user.accessToken}`);

      expect(res.status).toBe(200);
      expect(Array.isArray(res.body)).toBe(true);
      expect(res.body.length).toBe(2);
      const countryCodes = res.body.map((h: any) => h.countryCode);
      expect(countryCodes).toContain('US');
      expect(countryCodes).toContain('KR');
    });

    it('GET /holidays?countryCode=JP returns empty when not subscribed to JP', async () => {
      const user = await createTestUser(app);

      // Subscribe to US only via API (refreshHolidays is mocked)
      await request(app)
        .post('/api/holidays/subscribe')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ countryCode: 'US' });

      // Seed a US holiday
      await prisma.holiday.create({
        data: { countryCode: 'US', date: new Date(2025, 6, 4), name: 'Independence Day', year: 2025 },
      });

      const res = await request(app)
        .get('/api/holidays/holidays?year=2025&countryCode=JP')
        .set('Authorization', `Bearer ${user.accessToken}`);

      expect(res.status).toBe(200);
      expect(Array.isArray(res.body)).toBe(true);
      expect(res.body.length).toBe(0);
    });
  });
});
