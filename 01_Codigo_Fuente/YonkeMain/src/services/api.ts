import { Product } from '@/types';

// En el navegador, si no hay una URL configurada fuera de localhost, usa el mismo host
// que la página (localhost o la IP de red) con el puerto 3001 del backend.
// En el servidor de Next (render inicial) usa la URL configurada o localhost.
export function getApiUrl(): string {
  const configurada = process.env.NEXT_PUBLIC_API_URL;
  const esLocal = !configurada || configurada.includes('localhost');
  if (typeof window !== 'undefined' && esLocal) {
    return `${window.location.protocol}//${window.location.hostname}:3001/api`;
  }
  return configurada || 'http://localhost:3001/api';
}

export const api = {
  get: async (endpoint: string) => {
    const res = await fetch(`${getApiUrl()}${endpoint}`);
    if (!res.ok) throw new Error('Error en la petición get');
    return res.json();
  },
  post: async (endpoint: string, body: any) => {
    const res = await fetch(`${getApiUrl()}${endpoint}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body)
    });
    if (!res.ok) throw new Error('Error en la petición post');
    return res.json();
  }
};

// Formas que devuelve el backend en /api/publicaciones.
interface PublicacionLista {
  id: string;
  titulo: string;
  precio: number;
  condicion: string | null;
  nombre_yonque: string;
  imagen_thumb_url: string | null;
  imagen_medium_url?: string | null;
}

interface PublicacionDetalle {
  id: string;
  titulo: string;
  descripcion: string | null;
  precio: number;
  condicion: string | null;
  nombre_pieza: string | null;
  fotos: { thumb_url: string | null; medium_url: string | null; principal: boolean }[];
  yonque: {
    nombre: string;
    telefono: string | null;
    correo: string | null;
    ubicacion: {
      direccion: string | null;
      ciudad: string | null;
      estado: string | null;
      codigoPostal: string | null;
    };
  };
}

function desdeLista(p: PublicacionLista): Product {
  return {
    id: p.id,
    nombre: p.titulo,
    descripcion: '',
    precio: p.precio,
    categoria: p.condicion ?? '',
    imagen: p.imagen_medium_url ?? p.imagen_thumb_url ?? undefined,
  };
}

function desdeDetalle(p: PublicacionDetalle): Product {
  // El backend ya ordena la foto principal primero.
  const galeria = p.fotos
    .filter((f) => f.medium_url || f.thumb_url)
    .map((f) => ({
      grande: (f.medium_url ?? f.thumb_url) as string,
      miniatura: (f.thumb_url ?? f.medium_url) as string,
    }));
  return {
    id: p.id,
    nombre: p.titulo,
    descripcion: p.descripcion ?? '',
    precio: p.precio,
    categoria: p.nombre_pieza ?? p.condicion ?? '',
    imagen: galeria[0]?.grande,
    galeria,
    condicion: p.condicion ?? undefined,
    yonque: p.yonque,
  };
}

export interface FiltrosBusqueda {
  q?: string;
  categorias?: string[];
  precioMin?: number;
  precioMax?: number;
  limit?: number;
}

export const productosApi = {
  listar: async (limit = 20, offset = 0): Promise<Product[]> => {
    const data: PublicacionLista[] = await api.get(`/publicaciones?limit=${limit}&offset=${offset}`);
    return data.map(desdeLista);
  },
  buscar: async (f: FiltrosBusqueda = {}): Promise<Product[]> => {
    const p = new URLSearchParams({ limit: String(f.limit ?? 100) });
    if (f.q) p.set('q', f.q);
    if (f.categorias?.length) p.set('categoria', f.categorias.join(','));
    if (f.precioMin !== undefined) p.set('precio_min', String(f.precioMin));
    if (f.precioMax !== undefined) p.set('precio_max', String(f.precioMax));
    const data: PublicacionLista[] = await api.get(`/publicaciones?${p.toString()}`);
    return data.map(desdeLista);
  },
  obtener: async (id: string): Promise<Product> => {
    const data: PublicacionDetalle = await api.get(`/publicaciones/${encodeURIComponent(id)}`);
    return desdeDetalle(data);
  },
};
