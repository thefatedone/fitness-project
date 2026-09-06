"use client";
import {
  motion,
  useMotionValue,
  useMotionValueEvent,
  useSpring,
  useTransform,
  AnimatePresence,
} from "framer-motion";
import {
  Children,
  cloneElement,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from "react";
import "./Dock.css";

export type DockItemData = {
  icon: ReactNode;
  label: string;
  onClick?: () => void;
  className?: string;
};

type SpringOptions = {
  mass?: number;
  stiffness?: number;
  damping?: number;
};

function DockItem({
  children,
  className = "",
  onClick,
  mouseX,
  spring,
  distance,
  magnification,
  baseItemSize,
  label,
  forceVisible = false,
}: {
  children: ReactNode;
  className?: string;
  onClick?: () => void;
  mouseX: ReturnType<typeof useMotionValue<number>>;
  spring: SpringOptions;
  distance: number;
  magnification: number;
  baseItemSize: number;
  label: string;
  forceVisible?: boolean;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const isHovered = useMotionValue(0);

  const mouseDistance = useTransform(mouseX, (val) => {
    const rect = ref.current?.getBoundingClientRect() ?? {
      x: 0,
      width: baseItemSize,
    } as DOMRect;
    return val - rect.x - baseItemSize / 2;
  });

  const targetSize = useTransform(
    mouseDistance,
    [-distance, 0, distance],
    [baseItemSize, magnification, baseItemSize],
  );
  const size = useSpring(targetSize, spring);

  const handleKeyDown = (e: React.KeyboardEvent<HTMLDivElement>) => {
    if (e.key === "Enter" || e.key === " ") {
      e.preventDefault();
      onClick?.();
    }
  };

  return (
    <motion.div
      ref={ref}
      style={{
        width: size,
        height: size,
      }}
      onHoverStart={() => isHovered.set(1)}
      onHoverEnd={() => isHovered.set(0)}
      onClick={onClick}
      className={`dock-item ${className}`}
      tabIndex={0}
      role="button"
      aria-haspopup="true"
      aria-label={label}
      onKeyDown={handleKeyDown}
    >
      {Children.map(children, (child) =>
        cloneElement(
          child as React.ReactElement<{
            isHovered?: ReturnType<typeof useMotionValue<number>>;
            forceVisible?: boolean;
          }>,
          {
            isHovered,
            forceVisible,
          },
        ),
      )}
    </motion.div>
  );
}

function DockLabel({
  children,
  className = "",
  isHovered,
  forceVisible = false,
}: {
  children: ReactNode;
  className?: string;
  isHovered?: ReturnType<typeof useMotionValue<number>>;
  forceVisible?: boolean;
}) {
  // Initialize from the motion value's current state so the label is in
  // sync the moment it mounts. Without this, the label only appeared on
  // the first change-event after mount — which during fast interactions
  // (e.g. click-then-rehover) could miss the first 1 and flash hidden.
  const [isHoveredState, setIsHoveredState] = useState(
    isHovered?.get() === 1,
  );

  // useMotionValueEvent handles subscription/re-subscription for us, so the
  // label reliably tracks `isHovered` across parent re-renders, child
  // re-mounts, theme toggles, language switches, etc. The previous
  // useEffect + isHovered.on('change') pattern could drop the subscription
  // on re-render and leave `isVisible` stuck at its pre-render value.
  // `isHovered` is always provided by DockItem via cloneElement — the
  // non-null assertion is just to satisfy the MotionValue type.
  useMotionValueEvent(isHovered!, "change", (latest) => {
    setIsHoveredState(latest === 1);
  });

  // `forceVisible` lets the wrapper pin a label visible regardless of
  // hover state — used after a button press so the user gets visual
  // confirmation of which action they triggered (and stays visible long
  // enough to read the localised name, not just a flash).
  const isVisible = isHoveredState || forceVisible;

  return (
    <AnimatePresence>
      {isVisible && (
        <motion.div
          initial={{ opacity: 0, y: 0 }}
          animate={{ opacity: 1, y: -10 }}
          exit={{ opacity: 0, y: 0 }}
          transition={{ duration: 0.2 }}
          className={`dock-label ${className}`}
          role="tooltip"
          style={{ x: "-50%" }}
        >
          {children}
        </motion.div>
      )}
    </AnimatePresence>
  );
}

function DockIcon({
  children,
  className = "",
}: {
  children: ReactNode;
  className?: string;
}) {
  return <div className={`dock-icon ${className}`}>{children}</div>;
}

type DockProps = {
  items: DockItemData[];
  className?: string;
  spring?: SpringOptions;
  magnification?: number;
  distance?: number;
  panelHeight?: number;
  dockHeight?: number;
  baseItemSize?: number;
  /**
   * Index of the item whose label should be force-pinned visible (e.g. after
   * the user just pressed a button). Pass `null` to clear. Combined with the
   * hover state inside <DockLabel /> so the caller can briefly highlight
   * a button's localized name without the browser's focus-restoration bug
   * leaving the label stuck visible after returning from another page.
   */
  forceVisibleIndex?: number | null;
};

export default function Dock({
  items,
  className = "",
  spring = { mass: 0.1, stiffness: 150, damping: 12 },
  magnification = 70,
  distance = 200,
  panelHeight = 68,
  dockHeight = 256,
  baseItemSize = 50,
  forceVisibleIndex = null,
}: DockProps) {
  const mouseX = useMotionValue(Infinity);
  const isHovered = useMotionValue(0);

  const maxHeight = useMemo(
    () => Math.max(dockHeight, magnification + magnification / 2 + 4),
    [magnification, dockHeight],
  );
  // No-op transform that keeps the API stable but the height stays constant —
  // animating height on hover was making the whole panel bounce (the spring
  // oscillated around the panel's mid-height because the layout kept snapping
  // back and forth). The dock's magnification effect already provides the
  // macOS "alive" feel on hover; growing the panel container on top of that
  // is what was causing the shake.
  void maxHeight;

  return (
    <motion.div
      style={{ height: panelHeight, scrollbarWidth: "none" }}
      className="dock-outer"
    >
      <motion.div
        onMouseMove={({ pageX }) => {
          isHovered.set(1);
          mouseX.set(pageX);
        }}
        onMouseLeave={() => {
          isHovered.set(0);
          mouseX.set(Infinity);
        }}
        className={`dock-panel ${className}`}
        style={{ height: panelHeight }}
        role="toolbar"
        aria-label="Application dock"
      >
        {items.map((item, index) => (
          <DockItem
            key={index}
            onClick={item.onClick}
            className={item.className}
            mouseX={mouseX}
            spring={spring}
            distance={distance}
            magnification={magnification}
            baseItemSize={baseItemSize}
            label={item.label}
            forceVisible={forceVisibleIndex === index}
          >
            <DockIcon>{item.icon}</DockIcon>
            <DockLabel>{item.label}</DockLabel>
          </DockItem>
        ))}
      </motion.div>
    </motion.div>
  );
}
