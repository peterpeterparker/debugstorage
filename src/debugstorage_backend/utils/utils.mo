import Principal "mo:base/Principal";
import Array "mo:base/Array";

module {
  public func isPrincipalEqual(x : Principal, y : Principal) : Bool {x == y};

  public func isPrincipalNotEqual(x : Principal, y : Principal) : Bool {x != y};


  private func hasPrivilege(caller : Principal, privileges : [Text]) : Bool {
    func toPrincipal(entry : Text) : Principal {
      Principal.fromText(entry);
    };

    let principals : [Principal] = Array.map(privileges, toPrincipal);

    func filterAdmin(admin : Principal) : Bool {
      admin == caller;
    };

    let admin : ?Principal = Array.find(principals, filterAdmin);

    switch (admin) {
      case (null) {
        return false;
      };
      case (?admin) {
        return true;
      };
    };
  };
};
