interface SectionHeadingProps {
  title: string;
  subtitle?: string;
  align?: "center" | "left";
  className?: string;
}

/**
 * Standard "title + subtitle" header used at the top of every landing section.
 */
export default function SectionHeading({
  title,
  subtitle,
  align = "center",
  className = "",
}: SectionHeadingProps) {
  const alignClass = align === "center" ? "text-center mx-auto" : "text-left";

  return (
    <div className={`mb-16 ${align === "center" ? "text-center" : ""} ${className}`}>
      <h2 className="ln-heading text-4xl md:text-5xl tracking-tight mb-4">
        {title}
      </h2>
      {subtitle && (
        <p className={`ln-subheading max-w-2xl ${alignClass}`}>{subtitle}</p>
      )}
    </div>
  );
}
