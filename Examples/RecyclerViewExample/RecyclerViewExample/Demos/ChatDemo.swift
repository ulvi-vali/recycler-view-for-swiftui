import RecyclerView
import SwiftUI

struct ChatDemo: View {
    @State private var messages = SampleData.messages
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            RecyclerView(data: messages, layout: .linear(spacing: 6)) { message in
                MessageBubble(message: message)
            }
            .stackFromEnd(true)
            .dismissesKeyboardOnScroll()
            .verticalLayout(.matchParent)

            HStack(spacing: 8) {
                TextField("Message", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(send)
                Button("Send", action: send)
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(12)
            .background(.bar)
        }
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        messages.append(Message(id: (messages.last?.id ?? 0) + 1, text: text, isMine: true))
        draft = ""
    }
}
