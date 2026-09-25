import SwiftUI
import SwiftData

struct PendingView: View {
    @Query var operations: [PendingOperation]
    
    let stateColors: [String: Color] = [
        "pending": .black,
        "failed": .red,
        "successful": .green
    ]


    var body: some View {
        List{
            Section(header: Text("History Queue"), footer: Text("Operations proccess automatically when there is internet conection")){
                ForEach(operations) { index in
                    HStack{
                        Image(systemName: "clock").resizable().frame(width: 25, height: 25)
                        
                        VStack{
                            Text(index.type.displayName).font(.headline)
                            Text(index.productName).font(.subheadline)
                        }.padding(.leading, 6.2)
                        
                        Spacer()
                        
                        Text("\(index.state) (\(index.tries))").padding(.trailing, 15).font(.system(size:13)).foregroundStyle(stateColors[index.state] ?? .gray)

                    }
                    .padding(.vertical, 7)
                }
            }
        }
    }
}

#Preview {
    PendingView().modelContainer(for:[Product.self, PendingOperation.self], inMemory: true)
}
