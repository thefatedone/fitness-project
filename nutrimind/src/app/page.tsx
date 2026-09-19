import BrandLogo from "@/components/landing/BrandLogo";
import Hero from "@/components/landing/Hero";
import Features from "@/components/landing/Features";
import HowItWorks from "@/components/landing/HowItWorks";
import Testimonials from "@/components/landing/Testimonials";
import PrivacySection from "@/components/landing/PrivacySection";
import Pricing from "@/components/landing/Pricing";
import FAQ from "@/components/landing/FAQ";
import ContactSection from "@/components/landing/ContactSection";
import BrandParticleSection from "@/components/landing/BrandParticleSection";
import LandingDock from "@/components/landing/LandingDock";
import Footer from "@/components/landing/Footer";
import ScrollProgressBar from "@/components/ui/ScrollProgressBar";

export default function Home() {
  return (
    <main className="min-h-screen ln-section">
      <ScrollProgressBar />
      <BrandLogo />
      <Hero />
      <Features />
      <HowItWorks />
      <Testimonials />
      <PrivacySection />
      <Pricing />
      <FAQ />
      <ContactSection />
      <BrandParticleSection />
      <Footer />
      <LandingDock />
    </main>
  );
}
