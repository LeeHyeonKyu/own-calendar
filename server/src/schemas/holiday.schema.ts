import { z } from 'zod';

export const subscribeHolidaySchema = z.object({
  countryCode: z
    .string()
    .length(2, 'countryCode must be exactly 2 characters')
    .regex(/^[A-Z]{2}$/, 'countryCode must be 2 upper-case letters (ISO 3166-1 alpha-2)'),
});

export const getHolidaysQuerySchema = z.object({
  year: z.coerce
    .number()
    .int('year must be an integer')
    .min(1970, 'year must be at least 1970')
    .max(2100, 'year must be at most 2100'),
  month: z.coerce
    .number()
    .int('month must be an integer')
    .min(1, 'month must be at least 1')
    .max(12, 'month must be at most 12')
    .optional(),
  countryCode: z
    .string()
    .length(2)
    .regex(/^[A-Z]{2}$/)
    .optional(),
});
