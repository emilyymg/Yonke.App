import { useState, useEffect } from 'react';
import { productosApi } from '@/services/api';
import { Product } from '@/types';
import { useDebounce } from './useDebounce';

export interface FiltrosBusquedaUI {
  categorias: string[];
  precioMin?: number;
  precioMax?: number;
}

export function useSearch(
  initialQuery: string = '',
  filtros: FiltrosBusquedaUI = { categorias: [] }
) {
  const [query, setQuery] = useState(initialQuery);
  const [results, setResults] = useState<Product[]>([]);
  const [loading, setLoading] = useState(false);
  const debouncedQuery = useDebounce(query, 500);
  // Clave estable para no relanzar la búsqueda si el objeto de filtros se recrea sin cambios.
  const filtrosKey = JSON.stringify(filtros);

  useEffect(() => {
    // Ignora respuestas de búsquedas anteriores que lleguen tarde.
    let vigente = true;
    const f: FiltrosBusquedaUI = JSON.parse(filtrosKey);
    const search = async () => {
      setLoading(true);
      try {
        // Sin texto ni filtros devuelve el catálogo completo (límite máximo del backend = 100).
        const data = await productosApi.buscar({
          q: debouncedQuery || undefined,
          categorias: f.categorias,
          precioMin: f.precioMin,
          precioMax: f.precioMax,
        });
        if (vigente) setResults(data);
      } catch (e) {
        console.error(e);
        if (vigente) setResults([]);
      } finally {
        if (vigente) setLoading(false);
      }
    };
    search();
    return () => {
      vigente = false;
    };
  }, [debouncedQuery, filtrosKey]);

  return { query, setQuery, results, loading };
}
