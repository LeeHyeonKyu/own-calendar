import request from 'supertest';
import app from '../src/app';
import { createTestUser, prisma } from './setup';

describe('test_43_categories_suite', () => {
  describe('GET /api/categories', () => {
    it('test_43_list_empty: returns empty array for a new user', async () => {
      const user = await createTestUser(app);

      const res = await request(app)
        .get('/api/categories')
        .set('Authorization', `Bearer ${user.accessToken}`);

      expect(res.status).toBe(200);
      expect(Array.isArray(res.body)).toBe(true);
      expect(res.body).toHaveLength(0);
      // app.ts globalLimiter sets legacyHeaders: false — legacy rate-limit headers must be absent
      expect(res.headers['x-ratelimit-limit']).toBeUndefined();
      // Content-type must be JSON (relies on express.json() + res.json() chain through app.ts)
      expect(res.headers['content-type']).toMatch(/application\/json/);
    });
  });

  describe('POST /api/categories', () => {
    it('test_43_create_201: returns 201 with the posted name and colour', async () => {
      const user = await createTestUser(app);

      const res = await request(app)
        .post('/api/categories')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ name: 'Work', color: '#FF5733' });

      expect(res.status).toBe(201);
      expect(res.body.name).toBe('Work');
      expect(res.body.color).toBe('#FF5733');
      expect(res.body.id).toBeDefined();
      expect(res.body.userId).toBeDefined();
      // app.ts globalLimiter sets legacyHeaders: false — verify no legacy headers leak through
      expect(res.headers['x-ratelimit-limit']).toBeUndefined();
    });

    it('test_43_create_400_no_name: POST without name returns 400 with validate.ts error shape', async () => {
      const user = await createTestUser(app);

      const res = await request(app)
        .post('/api/categories')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({});

      expect(res.status).toBe(400);
      expect(res.body).toHaveProperty('error');
      expect(res.body).toHaveProperty('details');
    });
  });

  describe('PUT /api/categories/:id', () => {
    it('test_43_update_partial: changes only the supplied fields', async () => {
      const user = await createTestUser(app);

      // Create a category first
      const createRes = await request(app)
        .post('/api/categories')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ name: 'Original', color: '#AABBCC' });

      const categoryId = createRes.body.id;

      // Update only the name
      const updateRes = await request(app)
        .put(`/api/categories/${categoryId}`)
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ name: 'Updated' });

      expect(updateRes.status).toBe(200);
      expect(updateRes.body.name).toBe('Updated');
      // colour should remain unchanged
      expect(updateRes.body.color).toBe('#AABBCC');
    });

    it('test_43_update_cross_user: returns 4xx when updating another user category', async () => {
      const user1 = await createTestUser(app, { email: 'catuser1@example.com' });
      const user2 = await createTestUser(app, { email: 'catuser2@example.com' });

      // Create a category as user1
      const createRes = await request(app)
        .post('/api/categories')
        .set('Authorization', `Bearer ${user1.accessToken}`)
        .send({ name: 'User1 Category' });

      // Try to update as user2
      const res = await request(app)
        .put(`/api/categories/${createRes.body.id}`)
        .set('Authorization', `Bearer ${user2.accessToken}`)
        .send({ name: 'Hacked' });

      expect([403, 404]).toContain(res.status);
    });
  });

  describe('DELETE /api/categories/:id', () => {
    it('test_43_delete_204_with_default: returns 204 when a default category exists', async () => {
      const user = await createTestUser(app);

      // Manually insert a default category via Prisma so the delete path succeeds.
      // createTestUser returns { user: { id, ... }, accessToken, ... } so user.user.id is the DB id.
      await prisma.category.create({
        data: {
          name: 'Default',
          color: '#9E9E9E',
          isDefault: true,
          sortOrder: 0,
          user: { connect: { id: user.user.id } },
        },
      });

      // Create a non-default category to delete
      const createRes = await request(app)
        .post('/api/categories')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ name: 'To Delete', color: '#123456' });

      const res = await request(app)
        .delete(`/api/categories/${createRes.body.id}`)
        .set('Authorization', `Bearer ${user.accessToken}`);

      expect(res.status).toBe(204);

      // Verify the deleted category no longer appears in the list
      const listRes = await request(app)
        .get('/api/categories')
        .set('Authorization', `Bearer ${user.accessToken}`);

      const ids = listRes.body.map((c: any) => c.id);
      expect(ids).not.toContain(createRes.body.id);
    });

    it('test_43_delete_cross_user: returns 4xx when deleting another user category', async () => {
      const user1 = await createTestUser(app, { email: 'catdel1@example.com' });
      const user2 = await createTestUser(app, { email: 'catdel2@example.com' });

      // Create a category as user1
      const createRes = await request(app)
        .post('/api/categories')
        .set('Authorization', `Bearer ${user1.accessToken}`)
        .send({ name: 'User1 Delete Target' });

      // Try to delete as user2
      const res = await request(app)
        .delete(`/api/categories/${createRes.body.id}`)
        .set('Authorization', `Bearer ${user2.accessToken}`);

      expect([403, 404]).toContain(res.status);
    });

    it('test_43_delete_production_baseline: documents DELETE behaviour for standard-registered user without default category', async () => {
      const user = await createTestUser(app);

      // Create a non-default category (no default category exists for this user)
      const createRes = await request(app)
        .post('/api/categories')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ name: 'No Default Exists', color: '#ABCDEF' });

      // Attempt to delete without a default category present
      // The service will look for a default category to reassign items, find none, and return 500
      const res = await request(app)
        .delete(`/api/categories/${createRes.body.id}`)
        .set('Authorization', `Bearer ${user.accessToken}`);

      // Characterise actual production-baseline behaviour: 500 because
      // auth.service.ts register does not call createDefaultForUser,
      // so categoryService.delete hits the !defaultCategory branch (category.service.ts:99-101)
      expect(res.status).toBe(500);
      expect(res.body).toHaveProperty('error');
    });
  });
});
