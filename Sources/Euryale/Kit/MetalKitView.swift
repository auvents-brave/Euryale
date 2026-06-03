#if !os(watchOS)
    import MetalKit
    public import SwiftUI

    // MARK: - MetalKitView

    /// A SwiftUI view that renders a Metal shader inside an `MTKView`.
    ///
    /// The shader source is passed as a Metal Shading Language string and is
    /// compiled at view appearance.  Two built-in renderer kinds are provided
    /// via ``RendererKind`` — pick `.generic` for the default time/resolution
    /// uniforms pipeline, or `.mountains` for the procedural mountains demo.
    ///
    /// Available on iOS, iPadOS, tvOS, macOS, visionOS and Mac Catalyst
    /// (Metal is unavailable on watchOS).
    ///
    /// ```swift
    /// MetalKitView(source: shaderSource, rendererKind: .mountains)
    /// ```
    public struct MetalKitView: View {

        // MARK: Nested types

        /// Selects the built-in renderer pipeline used to drive the Metal view.
        public enum RendererKind {
            /// Default time-and-resolution uniforms pipeline.
            case generic
            /// Procedural mountains demo pipeline.
            case mountains
        }

        // MARK: Properties

        let source: String
        let rendererKind: RendererKind
        let mtkView = MTKView()
        let coordinator = makeCoordinator()

        // MARK: Init

        /// Creates a `MetalKitView` with the given shader source.
        ///
        /// - Parameters:
        ///   - source: Metal Shading Language source compiled at view appearance.
        ///   - rendererKind: Pipeline used to draw the shader.  Defaults to ``RendererKind/generic``.
        public init(source: String, rendererKind: RendererKind = .generic) {
            self.source = source
            self.rendererKind = rendererKind
        }

        // MARK: Body

        public var body: some View {
            WrapperView(view: mtkView)
                .ignoresSafeArea()
                .accessibilityIdentifier("MetalKitView.mtkView")
                .onAppear {
                    if mtkView.device == nil {
                        mtkView.device = MTLCreateSystemDefaultDevice()
                        mtkView.colorPixelFormat = .bgra8Unorm
                        mtkView.preferredFramesPerSecond = 60
                        mtkView.isPaused = false
                        mtkView.enableSetNeedsDisplay = false
                    }
                    if coordinator.renderer == nil, let renderer = makeRenderer() {
                        coordinator.renderer = renderer
                        mtkView.delegate = renderer
                    }
                }
                .onDisappear {
                    mtkView.delegate = nil
                    coordinator.renderer = nil
                }
        }

        // MARK: Helpers

        private func makeRenderer() -> (any MTKViewDelegate)? {
            switch rendererKind {
            case .generic:
                return Renderer(mtkView: mtkView, source: source)
            case .mountains:
                return MountainsRenderer(mtkView: mtkView, source: source)
            }
        }

        static func makeCoordinator() -> Coordinator { Coordinator() }

        // MARK: Coordinator

        final class Coordinator {
            var renderer: (any MTKViewDelegate)?
        }
    }

    // MARK: - Uniforms

    fileprivate struct Uniforms {
        var time: Float
    }

    // MARK: - MountainsUniforms

    fileprivate struct MountainsUniforms {
        var resolution: SIMD2<Float>
        var time: Float
        var padding: Float = 0
    }

    // MARK: - MountainsVertex

    fileprivate struct MountainsVertex {
        var position: SIMD2<Float>
        var uv: SIMD2<Float>
    }

    // MARK: - Renderer

    @MainActor
    final class Renderer: NSObject, MTKViewDelegate {

        // MARK: Properties
        private let device: any MTLDevice
        private let pipelineState: any MTLRenderPipelineState
        private var commandQueue: any MTLCommandQueue
        private var startTime: CFAbsoluteTime

        // MARK: Init

        init?(mtkView: MTKView, source: String) {
            guard let device = mtkView.device else { return nil }
            self.device = device
            commandQueue = device.makeCommandQueue()!
            startTime = CFAbsoluteTimeGetCurrent()

            let library = try? device.makeLibrary(source: source, options: nil)
            guard let library = library,
                  let vertexFunction = library.makeFunction(name: "vertex_main"),
                  let fragmentFunction = library.makeFunction(name: "fragment_main") else {
                return nil
            }

            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat

            do {
                pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            } catch {
                print("Error creating the pipeline: \(error)")
                return nil
            }
            super.init()
        }

        // MARK: Methods

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        }

        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let descriptor = view.currentRenderPassDescriptor else { return }

            // Calculate elapsed time to animate the water.
            let currentTime = Float(CFAbsoluteTimeGetCurrent() - startTime)
            var uniforms = Uniforms(time: currentTime)

            guard let commandBuffer = commandQueue.makeCommandBuffer(),
                  let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
                return
            }

            encoder.setRenderPipelineState(pipelineState)
            // Pass the `uniforms` parameter to the vertex and fragment shaders.
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
            // Draw two triangles (triangle strip) covering the entire screen.
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            encoder.endEncoding()

            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }

    // MARK: - MountainsRenderer

    @MainActor
    final class MountainsRenderer: NSObject, MTKViewDelegate {

        // MARK: Properties

        private let pipelineState: any MTLRenderPipelineState
        private let commandQueue: any MTLCommandQueue
        private let vertexBuffer: any MTLBuffer
        private let startTime: CFAbsoluteTime

        // MARK: Init

        init?(mtkView: MTKView, source: String) {
            guard let device = mtkView.device,
                  let commandQueue = device.makeCommandQueue() else {
                return nil
            }

            let library = try? device.makeLibrary(source: source, options: nil)
            guard let library,
                  let vertexFunction = library.makeFunction(name: "landscapeVertex"),
                  let fragmentFunction = library.makeFunction(name: "landscapeFragment") else {
                return nil
            }

            let vertices: [MountainsVertex] = [
                .init(position: SIMD2(-1, -1), uv: SIMD2(0, 0)),
                .init(position: SIMD2(1, -1), uv: SIMD2(1, 0)),
                .init(position: SIMD2(-1, 1), uv: SIMD2(0, 1)),
                .init(position: SIMD2(1, 1), uv: SIMD2(1, 1)),
            ]

            guard let vertexBuffer = device.makeBuffer(
                bytes: vertices,
                length: MemoryLayout<MountainsVertex>.stride * vertices.count
            ) else {
                return nil
            }

            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat

            do {
                pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            } catch {
                print("Error creating the mountains pipeline: \(error)")
                return nil
            }

            self.commandQueue = commandQueue
            self.vertexBuffer = vertexBuffer
            startTime = CFAbsoluteTimeGetCurrent()
            super.init()
        }

        // MARK: Methods

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        }

        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let descriptor = view.currentRenderPassDescriptor else { return }

            var uniforms = MountainsUniforms(
                resolution: SIMD2(
                    Float(view.drawableSize.width),
                    Float(view.drawableSize.height)
                ),
                time: Float(CFAbsoluteTimeGetCurrent() - startTime)
            )

            guard let commandBuffer = commandQueue.makeCommandBuffer(),
                  let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
                return
            }

            encoder.setRenderPipelineState(pipelineState)
            encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<MountainsUniforms>.stride, index: 1)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            encoder.endEncoding()

            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }

    #if DEBUG
        let seaShaderSource = """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexOut {
         float4 position [[position]];
         float2 uv;
        };

        vertex VertexOut vertex_main(uint id [[vertex_id]]) {
         float2 positions[4] = {
          float2(-1.0, -1.0),
          float2( 1.0, -1.0),
          float2(-1.0,  1.0),
          float2( 1.0,  1.0)
         };
         float2 uvs[4] = {
          float2(0.0, 1.0),
          float2(1.0, 1.0),
          float2(0.0, 0.0),
          float2(1.0, 0.0)
         };
         VertexOut out;
         out.position = float4(positions[id], 0, 1);
         out.uv = uvs[id];
         return out;
        }

        struct Uniforms { float time; };

        fragment float4 fragment_main(VertexOut in [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
         float wave = sin((in.uv.x * 10 + u.time * 0.8)) * 0.05
        	  + cos((in.uv.y * 8  + u.time * 0.6)) * 0.05;
         float3 base = float3(0.0, 0.4, 0.8);
         return float4(base + wave, 1.0);
        }
        """

        let mountainsShaderSource = """
        #include <metal_stdlib>
        using namespace metal;

        	// Procedural mountain landscape shader for Metal.
        	// Draws layered mountains with snowy peaks, rocky faces,
        	// green fields, and scattered pine trees.
        	//
        	// Typical host-side uniform layout:
        	//
        	// struct Uniforms {
        	//     float2 resolution;
        	//     float  time;
        	//     float  padding;
        	// };
        	//
        	// Pass UVs in [0,1] from a fullscreen quad.

        struct VertexIn {
        	float2 position [[attribute(0)]];
        	float2 uv       [[attribute(1)]];
        };

        struct VertexOut {
        	float4 position [[position]];
        	float2 uv;
        };

        struct Uniforms {
        	float2 resolution;
        	float time;
        	float padding;
        };

        vertex VertexOut landscapeVertex(
        	const device VertexIn *vertices [[buffer(0)]],
        	uint                  vid [[vertex_id]]
        ) {
        	VertexOut out;

        	out.position = float4(vertices[vid].position, 0.0, 1.0);
        	out.uv = vertices[vid].uv;
        	return out;
        }

        float hash11(float p) {
        	p = fract(p * 0.1031);
        	p *= p + 33.33;
        	p *= p + p;
        	return fract(p);
        }

        float hash21(float2 p) {
        	float3 p3 = fract(float3(p.xyx) * 0.1031);

        	p3 += dot(p3, p3.yzx + 33.33);
        	return fract((p3.x + p3.y) * p3.z);
        }

        float noise(float2 p) {
        	float2 i = floor(p);
        	float2 f = fract(p);

        	f = f * f * (3.0 - 2.0 * f);

        	float a = hash21(i + float2(0.0, 0.0));
        	float b = hash21(i + float2(1.0, 0.0));
        	float c = hash21(i + float2(0.0, 1.0));
        	float d = hash21(i + float2(1.0, 1.0));

        	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
        }

        float fbm(float2 p) {
        	float v = 0.0;
        	float a = 0.5;
        	float2 shift = float2(71.2, 19.7);

        	for (int i = 0; i < 5; ++i) {
        		v += a * noise(p);
        		p = p * 2.03 + shift;
        		a *= 0.5;
        	}

        	return v;
        }

        float mountainShape(float x, float offset, float scale, float height, float sharpness) {
        	float p = x * scale + offset;
        	float ridges = sin(p) * 0.55 + sin(p * 2.17 + 1.3) * 0.22 + sin(p * 4.41 + 0.7) * 0.08;

        	ridges = pow(abs(ridges), sharpness) * sign(ridges);
        	float detail = (fbm(float2(x * scale * 0.65 + offset, 3.7)) - 0.5) * 0.18;
        	return height + ridges * 0.22 + detail;
        }

        float treeMask(float2 uv, float xPos, float groundY, float scale, float rnd) {
        	float2 p = uv - float2(xPos, groundY);

        	p.x /= scale;
        	p.y /= scale;

        	float trunk = smoothstep(0.028, 0.008, abs(p.x)) *
        	smoothstep(-0.02, 0.02, p.y) *
        	smoothstep(0.22, 0.06, p.y);

        	float foliage = 0.0;
        	float3 centers[3] = {
        		float3(0.0, 0.16, 0.22),
        		float3(0.0, 0.28, 0.19),
        		float3(0.0, 0.39, 0.15)
        	};

        	for (int i = 0; i < 3; ++i) {
        		float2 q = p - centers[i].xy;
        		float tri = 1.0 - smoothstep(0.0, centers[i].z, max(abs(q.x) * 1.1 + q.y * 0.7, q.y));
        		foliage = max(foliage, tri);
        	}

        	float lean = (rnd - 0.5) * 0.12;
        	foliage *= smoothstep(0.55, -0.1, p.y + abs(p.x + lean) * 0.35);

        	return max(trunk * 0.7, foliage);
        }

        fragment float4 landscapeFragment(
        	VertexOut          in [[stage_in]],
        	constant Uniforms& u [[buffer(1)]]
        ) {
        	float2 uv = in.uv;
        	float2 p = uv;
        	float aspect = u.resolution.x / max(u.resolution.y, 1.0);
        	float2 suv = float2((uv.x - 0.5) * aspect + 0.5, uv.y);

        		// Sky
        	float3 skyTop = float3(0.33, 0.57, 0.90);
        	float3 skyMid = float3(0.58, 0.78, 0.95);
        	float3 horizon = float3(0.90, 0.95, 1.00);
        	float3 col = mix(horizon, skyTop, smoothstep(0.0, 1.0, uv.y));

        	col = mix(col, skyMid, exp(-pow((uv.y - 0.58) * 3.0, 2.0)));

        		// Sun glow
        	float2 sunPos = float2(0.76, 0.82);
        	float sunD = distance(suv, sunPos);
        	col += float3(1.0, 0.88, 0.60) * exp(-sunD * 10.0) * 0.38;
        	col += float3(1.0, 0.96, 0.85) * exp(-sunD * 35.0) * 0.22;

        		// Wispy clouds
        	float cloudBand = smoothstep(0.45, 0.85, uv.y) * (1.0 - smoothstep(0.82, 1.0, uv.y));
        	float clouds = fbm(float2(suv.x * 3.0 + u.time * 0.01, uv.y * 6.5));
        	clouds = smoothstep(0.58, 0.78, clouds) * cloudBand;
        	col = mix(col, col + float3(0.16), clouds * 0.28);

        		// Far mountains
        	float farY = mountainShape(suv.x, 0.4, 7.0, 0.49, 1.8);

        	if (uv.y < farY) {
        		float rockN = fbm(float2(suv.x * 8.0, uv.y * 8.0));
        		float3 mcol = mix(float3(0.44, 0.51, 0.58), float3(0.34, 0.40, 0.46), rockN);
        		float mist = smoothstep(0.18, 0.58, uv.y);
        		mcol = mix(float3(0.64, 0.72, 0.80), mcol, mist);
        		col = mcol;
        	}

        		// Mid mountains
        	float midY = mountainShape(suv.x, 2.1, 10.2, 0.39, 1.45);

        	if (uv.y < midY) {
        		float slopeNoise = fbm(float2(suv.x * 16.0, uv.y * 12.0));
        		float rock = smoothstep(0.0, 1.0, slopeNoise);
        		float3 rockCol = mix(float3(0.48, 0.44, 0.42), float3(0.28, 0.26, 0.25), rock);

        		float peak = 1.0 - smoothstep(0.0, 0.12, midY - uv.y);
        		float snowLine = smoothstep(0.78, 0.97, (midY - 0.25) * 2.2 + slopeNoise * 0.15 + 0.35);
        		float snow = peak * snowLine;

        		float2 cliffP = float2(suv.x * 28.0, uv.y * 20.0);
        		float striations = smoothstep(0.35, 0.8, abs(sin(cliffP.x + fbm(cliffP * 0.3) * 2.0)));
        		rockCol *= mix(1.0, 0.82, striations * 0.22);

        		float3 snowCol = float3(0.96, 0.97, 1.0);
        		col = mix(rockCol, snowCol, snow);
        	}

        		// Front field
        	float frontY = 0.21 + fbm(float2(suv.x * 4.0 + 12.0, 1.7)) * 0.08 + sin(suv.x * 8.0) * 0.015;

        	if (uv.y < frontY) {
        		float grassN = fbm(float2(suv.x * 9.0, uv.y * 16.0));
        		float3 grass = mix(float3(0.42, 0.68, 0.28), float3(0.58, 0.80, 0.36), grassN);
        		float fieldLight = smoothstep(0.0, 0.35, uv.y);
        		grass *= 0.92 + fieldLight * 0.28;
        		col = grass;

        			// Keep a bit of ground variation without bringing back the dark band.
        		float stones = smoothstep(0.76, 0.90, fbm(float2(suv.x * 18.0, uv.y * 24.0)));
        		col = mix(col, float3(0.58, 0.56, 0.46), stones * 0.10);
        	}

        		// Atmospheric grading
        	col = pow(clamp(col, 0.0, 1.0), float3(0.95));

        	return float4(col, 1.0);
        }
        """

    // MARK: - Previews

    #Preview("Sea") {
        MetalKitView(source: seaShaderSource)
    }

    #Preview("Mountains") {
        MetalKitView(source: mountainsShaderSource, rendererKind: .mountains)
    }
    #endif
#endif
