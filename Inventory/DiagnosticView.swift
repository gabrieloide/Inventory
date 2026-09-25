
import SwiftUI
import SwiftData

struct DiagnosticView: View {
    @State var istoggle: Bool = false
    @Query(filter: #Predicate<PendingOperation> { $0.state != "successful" }) var failedOperations: [PendingOperation]
    
    var body: some View {
        List{
            Text("Estado del Sistema")
                .listRowBackground(Color.clear)
                .font(.system(size: 30))
                .bold()
            
            Section{
                HStack{
                    Text("Red")
                    Spacer()
                    Image(systemName: "circle.fill").foregroundStyle(Color.green)
                    Text("Conected")
                }
                HStack{
                    Text("Last sync")
                    Spacer()
                    Text("5 minutes ago")
                }
                HStack{
                    Text("Data integrity")
                    Spacer()
                    Text("Optima")
                        .padding(.vertical, 9)
                        .padding(.horizontal, 12)
                        .background(
                            Color(.systemGray4),
                            in: RoundedRectangle(cornerRadius:100))
                        .font(.system(size: 13))
                }
            }
            Section(footer: Text("Use this option only if you notice discrepancies in the inventory. The operation may take a few minutes.")){
                Button(action: {
                    Task{
                        for operation in failedOperations { await operation.sync() }
                    }
                }){
                    HStack{
                        Image(systemName: "arrow.clockwise").foregroundStyle(Color.white)
                        Text("Force sync")
                            .foregroundStyle(Color.white)
                            .font(.system(size: 23))
                    }
                    .frame(maxWidth: .infinity)
                    
                    
                }.listRowBackground(Color.blue)
            }
            
            
            Section(header: Text("DEVELOPMENT & TESTING"))
            {
                Toggle(isOn: $istoggle){
                    
                    VStack(alignment: .leading){
                        Text("Simulate offline mode")
                            .foregroundStyle(Color.black)
                        Text("Force local saving of actions")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(.systemGray))
                        
                    }
                }
            }
        }
    }
}

#Preview {
    DiagnosticView()
}
