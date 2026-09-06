import Navbar from "@/components/landing/Navbar";
import Hero from "@/components/landing/Hero";
import Features from "@/components/landing/Features";
import HowItWorks from "@/components/landing/HowItWorks";
import Testimonials from "@/components/landing/Testimonials";
import Pricing from "@/components/landing/Pricing";
import ContactSection from "@/components/landing/ContactSection";
import BrandParticleSection from "@/components/landing/BrandParticleSection";
import LandingDock from "@/components/landing/LandingDock";
import Footer from "@/components/landing/Footer";
import ScrollProgressBar from "@/components/ui/ScrollProgressBar";

export default function Home() {
  return (
    <main className="min-h-screen ln-section">
      <ScrollProgressBar />
      <Navbar />
      <Hero />
      <Features />
      <HowItWorks />
      <Testimonials />
      <Pricing />
      <ContactSection />
      <BrandParticleSection />
      <Footer />
      <LandingDock />
    </main>
  );
}
