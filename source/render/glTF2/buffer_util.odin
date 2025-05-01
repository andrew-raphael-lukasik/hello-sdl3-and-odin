/*
Usage:

```odin
import gltf "gltf2"

buf := gltf.buffer_slice(data, accessor_index).([][3]f32)
for val, i in buf {
    // ...
}
```

Alternatively you can use a switch statement to handle multiple data formats:

```odin
buf := gltf.buffer_slice(data, accessor_index)
#partial switch vals in buf {
case [][4]u8:
    for val, i in vals { 
        // ...
    }
case [][4]i16:
    for val, i in vals {
        // ...
    }
}
```                           
*/
package gltf2

import "core:mem"

// All accessor type and component type combinations
Buffer_Slice :: union {
    []u8,
    []i8,
    []i16,
    []u16,
    []u32,
    []f32,
    [][2]u8,
    [][2]i8,
    [][2]i16,
    [][2]u16,
    [][2]u32,
    [][2]f32,
    [][3]u8,
    [][3]i8,
    [][3]i16,
    [][3]u16,
    [][3]u32,
    [][3]f32,
    [][4]u8,
    [][4]i8,
    [][4]i16,
    [][4]u16,
    [][4]u32,
    [][4]f32,
    []matrix[2, 2]u8,
    []matrix[2, 2]i8,
    []matrix[2, 2]i16,
    []matrix[2, 2]u16,
    []matrix[2, 2]u32,
    []matrix[2, 2]f32,
    []matrix[3, 3]u8,
    []matrix[3, 3]i8,
    []matrix[3, 3]i16,
    []matrix[3, 3]u16,
    []matrix[3, 3]u32,
    []matrix[3, 3]f32,
    []matrix[4, 4]u8,
    []matrix[4, 4]i8,
    []matrix[4, 4]i16,
    []matrix[4, 4]u16,
    []matrix[4, 4]u32,
    []matrix[4, 4]f32,
}

buffer_slice :: proc(data: ^Data, accessor_index: Integer) -> Buffer_Slice {
    accessor := data.accessors[accessor_index]

    if _, ok := accessor.sparse.?; ok {
        assert(false, "Sparse not supported")
        return nil
    }

    assert(accessor.buffer_view != nil, "buf_iter_make: selected accessor doesn't have buffer_view")
    buffer_view := data.buffer_views[accessor.buffer_view.?]

    switch v in data.buffers[buffer_view.buffer].uri {
    case string:
        assert(false, "URI is string")
        return nil
    case []byte:
        count := accessor.count
        component_size: u32 = 0
        switch accessor.component_type {
        case .Unsigned_Byte, .Byte:
            component_size = 1
        case .Short, .Unsigned_Short:
            component_size = 2
        case .Unsigned_Int, .Float:
            component_size = 4
        }

        start_byte := accessor.byte_offset + buffer_view.byte_offset
        stride, is_stride := buffer_view.byte_stride.?
        if !is_stride {
            switch accessor.type {
            case .Scalar:
                stride = component_size
            case .Vector2:
                stride = 2 * component_size
            case .Vector3:
                stride = 3 * component_size
            case .Vector4:
                stride = 4 * component_size
            case .Matrix2:
                stride = 4 * component_size
            case .Matrix3:
                stride = 9 * component_size
            case .Matrix4:
                stride = 16 * component_size
            }
            if stride == 0 {
                assert(false, "Could not determine element stride")
                return nil
            }
        }

        switch accessor.type {
        case .Scalar:
            switch accessor.component_type {
            case .Unsigned_Byte:
                result := make([]u8, count)
                for i in 0..<count {
                    result[i] = v[start_byte + i*stride]
                }
                return result
            case .Byte:
                result := make([]i8, count)
                for i in 0..<count {
                    result[i] = transmute(i8)v[start_byte + i*stride]
                }
                return result
            case .Short:
                result := make([]i16, count)
                for i in 0..<count {
                    result[i] = cast(i16)v[start_byte + i*stride]
                }
                return result
            case .Unsigned_Short:
                result := make([]u16, count)
                for i in 0..<count {
                    result[i] = cast(u16)v[start_byte + i*stride]
                }
                return result
            case .Unsigned_Int:
                result := make([]u32, count)
                for i in 0..<count {
                    result[i] = cast(u32)v[start_byte + i*stride]
                }
                return result
            case .Float:
                result := make([]f32, count)
                for i in 0..<count {
                    result[i] = cast(f32)v[start_byte + i*stride]
                }
                return result
            }

        case .Vector2:
            switch accessor.component_type {
            case .Unsigned_Byte:
                result := make([][2]u8, count)
                for i in 0..<count {
                    ptr := rawptr(&v[start_byte + i*stride])
                    result[i] = (cast(^[2]u8)ptr)^
                }
                return result
            case .Byte:
                result := make([][2]i8, count)
                for i in 0..<count {
                    ptr := rawptr(&v[start_byte + i*stride])
                    result[i] = (cast(^[2]i8)ptr)^
                }
                return result
            case .Short:
                result := make([][2]i16, count)
                for i in 0..<count {
                    ptr := rawptr(&v[start_byte + i*stride])
                    result[i] = (cast(^[2]i16)ptr)^
                }
                return result
            case .Unsigned_Short:
                result := make([][2]u16, count)
                for i in 0..<count {
                    ptr := rawptr(&v[start_byte + i*stride])
                    result[i] = (cast(^[2]u16)ptr)^
                }
                return result
            case .Unsigned_Int:
                result := make([][2]u32, count)
                for i in 0..<count {
                    ptr := rawptr(&v[start_byte + i*stride])
                    result[i] = (cast(^[2]u32)ptr)^
                }
                return result
            case .Float:
                result := make([][2]f32, count)
                for i in 0..<count {
                    ptr := rawptr(&v[start_byte + i*stride])
                    result[i] = (cast(^[2]f32)ptr)^
                }
                return result
            }

        // ... Podobnie dla Vector3, Vector4, Matrix2, Matrix3, Matrix4 ...
        case .Vector3:
            switch accessor.component_type {
            case .Unsigned_Byte:
                result := make([][3]u8, count)
                for i in 0..<count {
                    ptr := rawptr(&v[start_byte + i*stride])
                    result[i] = (cast(^[3]u8)ptr)^
                }
                return result
            case .Byte:
                result := make([][3]i8, count)
                for i in 0..<count {
                    ptr := rawptr(&v[start_byte + i*stride])
                    result[i] = (cast(^[3]i8)ptr)^
                }
                return result
            case .Short:
                result := make([][3]i16, count)
                for i in 0..<count {
                    ptr := rawptr(&v[start_byte + i*stride])
                    result[i] = (cast(^[3]i16)ptr)^
                }
                return result
            case .Unsigned_Short:
                result := make([][3]u16, count)
                for i in 0..<count {
                    ptr := rawptr(&v[start_byte + i*stride])
                    result[i] = (cast(^[3]u16)ptr)^
                }
                return result
            case .Unsigned_Int:
                result := make([][3]u32, count)
                for i in 0..<count {
                    ptr := rawptr(&v[start_byte + i*stride])
                    result[i] = (cast(^[3]u32)ptr)^
                }
                return result
            case .Float:
                result := make([][3]f32, count)
                for i in 0..<count {
                    ptr := rawptr(&v[start_byte + i*stride])
                    result[i] = (cast(^[3]f32)ptr)^
                }
                return result
            }

        case .Vector4:
            switch accessor.component_type {
            case .Unsigned_Byte:
                result := make([][4]u8, count)
                for i in 0..<count {
                    ptr := rawptr(&v[start_byte + i*stride])
                    result[i] = (cast(^[4]u8)ptr)^
                }
                return result
            case .Byte:
                result := make([][4]i8, count)
                for i in 0..<count {
                    ptr := rawptr(&v[start_byte + i*stride])
                    result[i] = (cast(^[4]i8)ptr)^
                }
                return result
            case .Short:
                result := make([][4]i16, count)
                for i in 0..<count {
                    ptr := rawptr(&v[start_byte + i*stride])
                    result[i] = (cast(^[4]i16)ptr)^
                }
                return result
            case .Unsigned_Short:
                result := make([][4]u16, count)
                for i in 0..<count {
                    ptr := rawptr(&v[start_byte + i*stride])
                    result[i] = (cast(^[4]u16)ptr)^
                }
                return result
            case .Unsigned_Int:
                result := make([][4]u32, count)
                for i in 0..<count {
                    ptr := rawptr(&v[start_byte + i*stride])
                    result[i] = (cast(^[4]u32)ptr)^
                }
                return result
            case .Float:
                result := make([][4]f32, count)
                for i in 0..<count {
                    ptr := rawptr(&v[start_byte + i*stride])
                    result[i] = (cast(^[4]f32)ptr)^
                }
                return result
            }

        case .Matrix2:
            #partial switch accessor.component_type {
            case .Unsigned_Byte:
                result := make([]matrix[2, 2]u8, count)
                for i in 0..<count {
                    ptr := rawptr(&v[start_byte + i*stride])
                    result[i] = (cast(^matrix[2, 2]u8)ptr)^
                }
                return result
            // ... Podobnie dla innych typów komponentów ...
            case .Float:
                result := make([]matrix[2, 2]f32, count)
                for i in 0..<count {
                    ptr := rawptr(&v[start_byte + i*stride])
                    result[i] = (cast(^matrix[2, 2]f32)ptr)^
                }
                return result
            }

        case .Matrix3:
            #partial switch accessor.component_type {
            // ... Implementacja podobna do Matrix2 ...
            case .Float:
                result := make([]matrix[3, 3]f32, count)
                for i in 0..<count {
                    ptr := rawptr(&v[start_byte + i*stride])
                    result[i] = (cast(^matrix[3, 3]f32)ptr)^
                }
                return result
            }

        case .Matrix4:
            #partial switch accessor.component_type {
            // ... Implementacja podobna do Matrix2 ...
            case .Float:
                result := make([]matrix[4, 4]f32, count)
                for i in 0..<count {
                    ptr := rawptr(&v[start_byte + i*stride])
                    result[i] = (cast(^matrix[4, 4]f32)ptr)^
                }
                return result
            }
        }
    }

    return nil
}
