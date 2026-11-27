import Link from 'next/link';
import Reveal from '@/components/Reveal';

const categories = [
  { name: 'Motor', href: '/search?categoria=Motor' },
  { name: 'Transmisión', href: '/search?categoria=Transmisi%C3%B3n' },
  { name: 'Suspensión', href: '/search?categoria=Suspensi%C3%B3n' },
  { name: 'Eléctrico', href: '/search?categoria=El%C3%A9ctrico' },
  { name: 'Interiores', href: '/search?categoria=Interiores' },
  { name: 'Carrocería', href: '/search?categoria=Carrocer%C3%ADa' },
];

export default function Categories() {
  return (
    <section className="py-24 bg-surface">
      <div className="max-w-7xl mx-auto px-6">
        <Reveal>
          <h2 className="text-3xl font-extrabold text-ink mb-10 tracking-display">
            Explorar por categoría
          </h2>
        </Reveal>
        <Reveal delay={80}>
          <div className="flex flex-nowrap gap-x-6 xl:gap-x-8 overflow-x-auto pb-2">
            {categories.map((category) => (
              <Link
                key={category.name}
                href={category.href}
                className="whitespace-nowrap text-base sm:text-xl xl:text-2xl font-extrabold text-ink-secondary hover:text-accent transition-colors duration-150 tracking-display"
              >
                {category.name}
              </Link>
            ))}
          </div>
        </Reveal>
      </div>
    </section>
  );
}
