/*
    This file is part of darktable,
    copyright (c) 2011-2012 ulrich pegelow.

    darktable is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    darktable is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with darktable.  If not, see <http://www.gnu.org/licenses/>.
*/

const sampler_t sampleri =  CLK_NORMALIZED_COORDS_FALSE | CLK_ADDRESS_CLAMP_TO_EDGE | CLK_FILTER_NEAREST;
const sampler_t samplerf =  CLK_NORMALIZED_COORDS_FALSE | CLK_ADDRESS_CLAMP_TO_EDGE | CLK_FILTER_LINEAR;


/* This is gaussian blur in Lab space. Please mind: in contrast to most of DT's other openCL kernels,
   the kernels in this package expect part/all of their input/output buffers in form of vectors. This
   is needed to have read-write access to some buffers which openCL does not offer for image object. */


kernel void 
gaussian_transpose_4c(global float4 *in, global float4 *out, unsigned int width, unsigned int height, 
                      unsigned int blocksize, local float4 *buffer)
{
  unsigned int x = get_global_id(0);
  unsigned int y = get_global_id(1);

  if((x < width) && (y < height))
  {
    const unsigned int iindex = mad24(y, width, x);
    buffer[mad24(get_local_id(1), blocksize + 1, get_local_id(0))] = in[iindex];
  }

  barrier(CLK_LOCAL_MEM_FENCE);

  x = mad24(get_group_id(1), blocksize, get_local_id(0));
  y = mad24(get_group_id(0), blocksize, get_local_id(1));

  if((x < height) && (y < width))
  {
    const unsigned int oindex = mad24(y, height, x);
    out[oindex] = buffer[mad24(get_local_id(0), blocksize + 1, get_local_id(1))];
  }
}


kernel void 
gaussian_transpose_1c(global float *in, global float *out, unsigned int width, unsigned int height, 
                      unsigned int blocksize, local float *buffer)
{
  unsigned int x = get_global_id(0);
  unsigned int y = get_global_id(1);

  if((x < width) && (y < height))
  {
    const unsigned int iindex = mad24(y, width, x);
    buffer[mad24(get_local_id(1), blocksize + 1, get_local_id(0))] = in[iindex];
  }

  barrier(CLK_LOCAL_MEM_FENCE);

  x = mad24(get_group_id(1), blocksize, get_local_id(0));
  y = mad24(get_group_id(0), blocksize, get_local_id(1));

  if((x < height) && (y < width))
  {
    const unsigned int oindex = mad24(y, height, x);
    out[oindex] = buffer[mad24(get_local_id(0), blocksize + 1, get_local_id(1))];
  }
}


kernel void 
gaussian_column_4c(global float4 *in, global float4 *out, unsigned int width, unsigned int height,
                  const float a0, const float a1, const float a2, const float a3, const float b1, const float b2,
                  const float coefp, const float coefn, const float4 Labmax, const float4 Labmin)
{
  const unsigned int x = get_global_id(0);

  if(x >= width) return;

  float4 xp = (float4)0.0f;
  float4 yb = (float4)0.0f;
  float4 yp = (float4)0.0f;
  float4 xc = (float4)0.0f;
  float4 yc = (float4)0.0f;
  float4 xn = (float4)0.0f;
  float4 xa = (float4)0.0f;
  float4 yn = (float4)0.0f;
  float4 ya = (float4)0.0f;

  // forward filter
  xp = clamp(in[x], Labmin, Labmax); // 0*width+x
  yb = xp * coefp;
  yp = yb;

 
  for(int y=0; y<height; y++)
  {
    const int idx = mad24((unsigned int)y, width, x);

    xc = clamp(in[idx], Labmin, Labmax);
    yc = (a0 * xc) + (a1 * xp) - (b1 * yp) - (b2 * yb);

    xp = xc;
    yb = yp;
    yp = yc;

    out[idx] = yc;

  }

  // backward filter
  xn = clamp(in[mad24(height - 1, width, x)], Labmin, Labmax);
  xa = xn;
  yn = xn * coefn;
  ya = yn;


  for(int y=height-1; y>-1; y--)
  {
    const int idx = mad24((unsigned int)y, width, x);

    xc = clamp(in[idx], Labmin, Labmax);
    yc = (a2 * xn) + (a3 * xa) - (b1 * yn) - (b2 * ya);

    xa = xn; 
    xn = xc; 
    ya = yn; 
    yn = yc;

    out[idx] += yc;

  }
}

kernel void 
gaussian_column_1c(global float *in, global float *out, unsigned int width, unsigned int height,
                  const float a0, const float a1, const float a2, const float a3, const float b1, const float b2,
                  const float coefp, const float coefn, const float Labmax, const float Labmin)
{
  const unsigned int x = get_global_id(0);

  if(x >= width) return;

  float xp = 0.0f;
  float yb = 0.0f;
  float yp = 0.0f;
  float xc = 0.0f;
  float yc = 0.0f;
  float xn = 0.0f;
  float xa = 0.0f;
  float yn = 0.0f;
  float ya = 0.0f;

  // forward filter
  xp = clamp(in[x], Labmin, Labmax); // 0*width+x
  yb = xp * coefp;
  yp = yb;

 
  for(int y=0; y<height; y++)
  {
    const int idx = mad24((unsigned int)y, width, x);

    xc = clamp(in[idx], Labmin, Labmax);
    yc = (a0 * xc) + (a1 * xp) - (b1 * yp) - (b2 * yb);

    xp = xc;
    yb = yp;
    yp = yc;

    out[idx] = yc;

  }

  // backward filter
  xn = clamp(in[mad24(height - 1, width, x)], Labmin, Labmax);
  xa = xn;
  yn = xn * coefn;
  ya = yn;


  for(int y=height-1; y>-1; y--)
  {
    const int idx = mad24((unsigned int)y, width, x);

    xc = clamp(in[idx], Labmin, Labmax);
    yc = (a2 * xn) + (a3 * xa) - (b1 * yn) - (b2 * ya);

    xa = xn; 
    xn = xc; 
    ya = yn; 
    yn = yc;

    out[idx] += yc;

  }
}



float
lookup_unbounded(read_only image2d_t lut, const float x, global float *a)
{
  // in case the curve is marked as linear, return the fast
  // path to linear unbounded (does not clip x at 1)
  if(a[0] >= 0.0f)
  {
    if(x < 1.0f)
    {
      const int xi = clamp(x*65535.0f, 0.0f, 65535.0f);
      const int2 p = (int2)((xi & 0xff), (xi >> 8));
      return read_imagef(lut, sampleri, p).x;
    }
    else return a[1] * native_powr(x*a[0], a[2]);
  }
  else return x;
}


kernel void 
lowpass_mix(read_only image2d_t in, write_only image2d_t out, unsigned int width, unsigned int height, const float saturation, 
            read_only image2d_t table, global float *a)
{
  const unsigned int x = get_global_id(0);
  const unsigned int y = get_global_id(1);

  if(x >= width || y >= height) return;

  float4 i = read_imagef(in, sampleri, (int2)(x, y));
  float4 o;

  const float4 Labmin = (float4)(0.0f, -128.0f, -128.0f, 0.0f);
  const float4 Labmax = (float4)(100.0f, 128.0f, 128.0f, 1.0f);

  o.x = lookup_unbounded(table, i.x/100.0f, a);
  o.y = clamp(i.y*saturation, Labmin.y, Labmax.y);
  o.z = clamp(i.z*saturation, Labmin.z, Labmax.z);
  o.w = i.w;

  write_imagef(out, (int2)(x, y), o);
}



float4
overlay(const float4 in_a, const float4 in_b, const float opacity, const float transform, const float ccorrect)
{
  /* a contains underlying image; b contains mask */

  const float4 scale = (float4)(100.0f, 128.0f, 128.0f, 1.0f);
  const float4 min = (float4)(0.0f, -1.0f, -1.0f, 0.0f);
  const float4 max = (float4)(1.0f, 1.0f, 1.0f, 1.0f);
  const float lmin = 0.0f;
  const float lmax = 1.0f;       /* max + fabs(min) */
  const float halfmax = 0.5f;    /* lmax / 2.0f */
  const float doublemax = 2.0f;  /* lmax * 2.0f */

  float4 a = in_a / scale;
  float4 b = in_b / scale;

  float lb = clamp((b.x - halfmax) * sign(opacity) + halfmax, lmin, lmax);
  float opacity2 = opacity*opacity;

  while(opacity2 > 0.0f)
  {
    float lref = a.x > 0.01f ? a.x : 0.01f;
    float href = a.x < 0.99f ? a.x : 0.99f;
    float la = clamp(a.x + fabs(min.x), lmin, lmax);

    float chunk = opacity2 > 1.0f ? 1.0f : opacity2;
    float optrans = chunk * transform;
    opacity2 -= 1.0f;

    a.x = clamp(la * (1.0f - optrans) + (la > halfmax ? 
                                            lmax - (lmax - doublemax * (la - halfmax)) * (lmax-lb) : 
                                            doublemax * la * lb) * optrans, lmin, lmax) - fabs(min.x);

    a.y = clamp(a.y * (1.0f - optrans) + (a.y + b.y) * (a.x/lref * ccorrect + (1.0f - a.x)/(1.0f - href) * (1.0f - ccorrect)) * optrans, min.y, max.y);

    a.z = clamp(a.z * (1.0f - optrans) + (a.z + b.z) * (a.x/lref * ccorrect + (1.0f - a.x)/(1.0f - href) * (1.0f - ccorrect)) * optrans, min.z, max.z);

  }
  /* output scaled back pixel */
  return a * scale;
}


kernel void 
shadows_highlights_mix(read_only image2d_t in, read_only image2d_t mask, write_only image2d_t out, 
                       unsigned int width, unsigned int height, 
                       const float shadows, const float highlights, const float compress,
                       const float shadows_ccorrect, const float highlights_ccorrect)
{
  const unsigned int x = get_global_id(0);
  const unsigned int y = get_global_id(1);

  if(x >= width || y >= height) return;

  float4 io = read_imagef(in, sampleri, (int2)(x, y));
  float w = io.w;
  float4 m = (float4)0.0f;
  float xform;

  const float4 Labmin = (float4)(0.0f, -128.0f, -128.0f, 0.0f);
  const float4 Labmax = (float4)(100.0f, 128.0f, 128.0f, 1.0f);

  /* blurred, inverted and desaturaed mask in m */
  m.x = 100.0f - read_imagef(mask, sampleri, (int2)(x, y)).x;

  /* overlay highlights */
  xform = clamp(1.0f - 0.01f * m.x/(1.0f-compress), 0.0f, 1.0f);
  io = overlay(io, m, -highlights, xform, 1.0f - highlights_ccorrect);

  /* overlay shadows */
  xform = clamp(0.01f * m.x/(1.0f-compress) - compress/(1.0f-compress), 0.0f, 1.0f);
  io = overlay(io, m, shadows, xform, shadows_ccorrect);

  io.w = w;
  write_imagef(out, (int2)(x, y), io);
}


