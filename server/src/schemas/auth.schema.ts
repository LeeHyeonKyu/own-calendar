import { z } from 'zod';

// 개인 프로젝트라 id/pw 형식·길이 제한을 의도적으로 두지 않는다.
// email 필드는 DB의 unique 식별자로 쓰이지만 형식 검증은 하지 않는다
// (예: "hk" 같은 짧은 값도 허용).
export const registerSchema = z.object({
  email: z.string(),
  name: z.string(),
  password: z.string(),
});

export const loginSchema = z.object({
  email: z.string(),
  password: z.string(),
  rememberMe: z.boolean().optional(),
});

export const refreshSchema = z.object({
  refreshToken: z.string(),
});

export type RegisterInput = z.infer<typeof registerSchema>;
export type LoginInput = z.infer<typeof loginSchema>;
export type RefreshInput = z.infer<typeof refreshSchema>;
