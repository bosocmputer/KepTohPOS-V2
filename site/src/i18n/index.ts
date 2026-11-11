import th from './th.json';
import en from './en.json';
import zh from './zh.json';

export const copy = { th, en, zh };
export type Locale = keyof typeof copy;
export const locales: Locale[] = ['th', 'en', 'zh'];
export const htmlLang: Record<Locale, string> = { th: 'th', en: 'en', zh: 'zh-Hans' };
export const ogLocale: Record<Locale, string> = { th: 'th_TH', en: 'en_US', zh: 'zh_CN' };
export const langName: Record<Locale, string> = { th: 'ไทย', en: 'English', zh: '简体中文' };
export const langShort: Record<Locale, string> = { th: 'TH', en: 'EN', zh: '中文' };

export type Page = 'home' | 'privacy';

export function pagePath(locale: Locale, page: Page = 'home'): string {
  const base = locale === 'th' ? '/' : `/${locale}/`;
  return page === 'home' ? base : `${base}privacy/`;
}
