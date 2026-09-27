import prisma from '../lib/prisma';
import { config } from '../config';

export const holidayService = {
  async subscribe(userId: string, countryCode: string) {
    const existing = await prisma.holidaySubscription.findUnique({
      where: { userId_countryCode: { userId, countryCode } },
    });
    if (existing) return existing;

    const subscription = await prisma.holidaySubscription.create({
      data: { userId, countryCode },
    });

    // Fetch holidays for the current year if not cached
    const year = new Date().getFullYear();
    await holidayService.refreshHolidays(countryCode, year);

    return subscription;
  },

  async unsubscribe(userId: string, countryCode: string) {
    await prisma.holidaySubscription.deleteMany({
      where: { userId, countryCode },
    });
    return { success: true };
  },

  async listSubscriptions(userId: string) {
    return prisma.holidaySubscription.findMany({
      where: { userId },
      orderBy: { createdAt: 'asc' },
    });
  },

  async getHolidays(userId: string, year: number, month?: number, countryCode?: string) {
    const subscriptions = await prisma.holidaySubscription.findMany({
      where: { userId },
    });

    if (subscriptions.length === 0) return [];

    let countryCodes = subscriptions.map((s) => s.countryCode);

    // If countryCode filter is provided, narrow to only that country (must be subscribed)
    if (countryCode) {
      countryCodes = countryCodes.filter((c) => c === countryCode);
      if (countryCodes.length === 0) return [];
    }

    // Ensure holidays are cached for requested year
    for (const code of countryCodes) {
      const cached = await prisma.holiday.findFirst({
        where: { countryCode: code, year },
      });
      if (!cached) {
        await holidayService.refreshHolidays(code, year);
      }
    }

    const where: any = {
      countryCode: { in: countryCodes },
      year,
    };

    if (month !== undefined) {
      const startDate = new Date(year, month - 1, 1);
      const endDate = new Date(year, month, 0, 23, 59, 59);
      where.date = { gte: startDate, lte: endDate };
    }

    return prisma.holiday.findMany({
      where,
      orderBy: { date: 'asc' },
    });
  },

  async refreshHolidays(countryCode: string, year: number) {
    let holidays: Array<{ date: Date; name: string }> = [];

    if (countryCode === 'KR') {
      holidays = await fetchKoreanHolidays(year);
    } else {
      holidays = await fetchNagerHolidays(countryCode, year);
    }

    if (holidays.length === 0) return;

    // Upsert each holiday
    for (const h of holidays) {
      await prisma.holiday.upsert({
        where: { countryCode_date: { countryCode, date: h.date } },
        create: {
          countryCode,
          date: h.date,
          name: h.name,
          year,
        },
        update: { name: h.name, year },
      });
    }
  },
};

async function fetchKoreanHolidays(year: number): Promise<Array<{ date: Date; name: string }>> {
  const apiKey = config.koreaHolidayApiKey;
  if (!apiKey) {
    // Fallback: use Nager.Date for Korea too
    return fetchNagerHolidays('KR', year);
  }

  const holidays: Array<{ date: Date; name: string }> = [];

  for (let month = 1; month <= 12; month++) {
    const url = `https://apis.data.go.kr/B090041/openapi/service/SpcdeInfoService/getRestDeInfo?serviceKey=${encodeURIComponent(apiKey)}&solYear=${year}&solMonth=${String(month).padStart(2, '0')}&_type=json&numOfRows=50`;

    try {
      const res = await fetch(url);
      if (!res.ok) continue;
      const data: any = await res.json();

      const items = data?.response?.body?.items?.item;
      if (!items) continue;

      const itemList = Array.isArray(items) ? items : [items];
      for (const item of itemList) {
        if (item.isHoliday !== 'Y') continue;
        const dateStr = String(item.locdate);
        const date = new Date(
          parseInt(dateStr.substring(0, 4)),
          parseInt(dateStr.substring(4, 6)) - 1,
          parseInt(dateStr.substring(6, 8)),
        );
        holidays.push({ date, name: item.dateName });
      }
    } catch {
      continue;
    }
  }

  return holidays;
}

async function fetchNagerHolidays(countryCode: string, year: number): Promise<Array<{ date: Date; name: string }>> {
  const url = `https://date.nager.at/api/v3/PublicHolidays/${year}/${countryCode}`;

  try {
    const res = await fetch(url);
    if (!res.ok) return [];
    const data = await res.json() as Array<{ date: string; localName: string; name: string }>;

    return data.map((h) => ({
      date: new Date(h.date),
      name: h.localName || h.name,
    }));
  } catch {
    return [];
  }
}
