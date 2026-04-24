import SwiftUI

struct StartOverlayView: View {
    let onStart: (MappingConfig, MappingConfig, Bool) -> Void

    @State private var config = DEFAULT_MAPPING
    @State private var hydraConfig = DEFAULT_HYDRA_MAPPING
    @State private var advanced = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Title
                    VStack(spacing: 4) {
                        Text("HandStrudel")
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                        Text("hand-tracking musical instrument")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.top, 40)

                    // Advanced toggle
                    Toggle(isOn: $advanced) {
                        Text("advanced mode")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                    .padding(.horizontal, 40)
                    .onChange(of: advanced) { isAdvanced in
                        if isAdvanced {
                            config = DEFAULT_ADVANCED_MAPPING
                            hydraConfig = DEFAULT_ADVANCED_HYDRA_MAPPING
                        } else {
                            config = DEFAULT_MAPPING
                            hydraConfig = DEFAULT_HYDRA_MAPPING
                        }
                    }

                    // Mapping config
                    HStack(alignment: .top, spacing: 16) {
                        handConfigSection(side: "Left Hand", color: .green,
                                          musicMapping: $config.left, hydraMapping: $hydraConfig.left)
                        handConfigSection(side: "Right Hand", color: .pink,
                                          musicMapping: $config.right, hydraMapping: $hydraConfig.right)
                    }
                    .padding(.horizontal, 16)

                    // Start button
                    Button(action: { onStart(config, hydraConfig, advanced) }) {
                        Text("START")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.black)
                            .frame(width: 200, height: 44)
                            .background(Color.green)
                            .cornerRadius(8)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private func handConfigSection(side: String, color: Color,
                                    musicMapping: Binding<[String: String]>,
                                    hydraMapping: Binding<[String: String]>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(side)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(color)

            let axes = advanced ? AXIS_DEFS : AXIS_DEFS.filter(\.basic)
            ForEach(axes) { axis in
                VStack(alignment: .leading, spacing: 2) {
                    Text(axis.label)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))

                    // Music param picker
                    paramPicker(binding: musicMapping[axis.key],
                                options: musicParamOptions, color: color)

                    // Hydra param picker
                    paramPicker(binding: hydraMapping[axis.key],
                                options: hydraParamOptions, color: .purple)
                }
            }
        }
    }

    private func paramPicker(binding: Binding<String?>, options: [(String, String)], color: Color) -> some View {
        let safeBinding = Binding<String>(
            get: { binding.wrappedValue ?? "none" },
            set: { binding.wrappedValue = $0 }
        )

        return Menu {
            ForEach(options, id: \.0) { id, label in
                Button(label) { safeBinding.wrappedValue = id }
            }
        } label: {
            Text(options.first(where: { $0.0 == safeBinding.wrappedValue })?.1 ?? "none")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(safeBinding.wrappedValue == "none" ? .white.opacity(0.3) : color)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.05))
                .cornerRadius(4)
        }
    }

    private var musicParamOptions: [(String, String)] {
        var opts: [(String, String)] = [("none", "none"), ("save", "save")]
        for def in PARAM_DEFS {
            opts.append((def.id, def.label))
        }
        return opts
    }

    private var hydraParamOptions: [(String, String)] {
        var opts: [(String, String)] = [("none", "none")]
        for def in HYDRA_PARAM_DEFS {
            opts.append((def.id, def.label))
        }
        return opts
    }
}
