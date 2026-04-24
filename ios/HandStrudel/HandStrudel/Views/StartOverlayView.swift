import SwiftUI

struct StartOverlayView: View {
    let status: String
    let onStart: (MappingConfig, MappingConfig, Bool) -> Void

    @State private var config = DEFAULT_MAPPING
    @State private var hydraConfig = DEFAULT_HYDRA_MAPPING
    @State private var advanced = false
    @State private var starting = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.9).ignoresSafeArea()

            VStack(spacing: 10) {
                // Title
                Text("HandStrudel")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
                Text("hand-tracking musical instrument")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))

                // Advanced toggle
                HStack {
                    Toggle(isOn: $advanced) {
                        Text("advanced")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                    .fixedSize()
                }
                .onChange(of: advanced) { isAdvanced in
                    if isAdvanced {
                        config = DEFAULT_ADVANCED_MAPPING
                        hydraConfig = DEFAULT_ADVANCED_HYDRA_MAPPING
                    } else {
                        config = DEFAULT_MAPPING
                        hydraConfig = DEFAULT_HYDRA_MAPPING
                    }
                }

                // Mapping config — side by side
                HStack(alignment: .top, spacing: 20) {
                    handConfigSection(side: "L", color: .green,
                                      musicMapping: $config.left, hydraMapping: $hydraConfig.left)
                    handConfigSection(side: "R", color: .pink,
                                      musicMapping: $config.right, hydraMapping: $hydraConfig.right)
                }

                // Start button + status
                if starting {
                    Text(status)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.green.opacity(0.7))
                        .padding(.top, 4)
                } else {
                    Button(action: {
                        starting = true
                        onStart(config, hydraConfig, advanced)
                    }) {
                        Text("START")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.black)
                            .frame(width: 140, height: 36)
                            .background(Color.green)
                            .cornerRadius(6)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func handConfigSection(side: String, color: Color,
                                    musicMapping: Binding<[String: String]>,
                                    hydraMapping: Binding<[String: String]>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(side)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(color)

            let axes = advanced ? AXIS_DEFS : AXIS_DEFS.filter(\.basic)
            ForEach(axes) { axis in
                HStack(spacing: 4) {
                    Text(axis.label)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(width: 55, alignment: .trailing)

                    paramPicker(binding: musicMapping[axis.key],
                                options: musicParamOptions, color: color)

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
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(safeBinding.wrappedValue == "none" ? .white.opacity(0.3) : color)
                .frame(minWidth: 44)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.05))
                .cornerRadius(3)
        }
    }

    private var musicParamOptions: [(String, String)] {
        var opts: [(String, String)] = [("none", "none"), ("save", "save")]
        for def in PARAM_DEFS { opts.append((def.id, def.label)) }
        return opts
    }

    private var hydraParamOptions: [(String, String)] {
        var opts: [(String, String)] = [("none", "none")]
        for def in HYDRA_PARAM_DEFS { opts.append((def.id, def.label)) }
        return opts
    }
}
