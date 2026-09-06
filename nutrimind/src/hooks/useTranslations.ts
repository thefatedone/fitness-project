import { useLanguage } from "@/context/LanguageContext";
import en from "@/messages/en.json";
import ka from "@/messages/ka.json";
import ru from "@/messages/ru.json";

type MessageNamespace = Record<string, string>;
type MessageBundle = Record<string, MessageNamespace>;

const messages: Record<string, MessageBundle> = { en, ka, ru };

function capitalize(str: string): string {
  return str.charAt(0).toUpperCase() + str.slice(1);
}

export function useTranslations(namespace: string = "hero") {
  const { locale } = useLanguage();
  const allMessages = messages[locale];
  const namespaceKey = capitalize(namespace);

  const t = (key: string): string => {
    const value = allMessages?.[namespaceKey]?.[key];
    if (value === undefined) {
      return key;
    }
    return value;
  };

  return { t, locale };
}
