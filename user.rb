# La manière la plus simple de stocker un arbre en base de donnée est de stocké l'identifiant parent de chaque élément.
# Cette solution est cependant très coûteuse en requète récursive lorsque l'on veut parcourir l'arbre.

# Afin d'améliorer la performance des requêtes, on utilise le concept de l'arbre intervallaire.
# Chaque utilisateur est identifié par sa borne gauche qui est unique et a borne droite qui est unique. Unicité des bornes permet de garantir la cohérence de l'arbre.
# Les filleuls d'un utilisateurs ont des bornes comprises entre les siennes
# Les utilisateurs n'ayant parrainé personnes sont les utilisateurs ayant un intervalle de 1 entre leur borne.

# On peut ajouter le niveau de l'utilisateur.
# Ainsi les parrains initiaux sont toujours de niveau 1.
# Les filleuls directs sont les utilisateurs du niveau inférieur dont les bornes sont comprises dans celle du parrain.
# Le nombre de filleul total d'un parrain est égale à (intervalle - 1) / 2

# Soit les champs en base de données :
# :id
# :left
# :right
# :level
# Et les index unique suivant
# :left
# :right
class User < ActiveRecord::Base
  
  scope :ascendant, lambda {|user| user[:level] == 1 ? none : where("left < ? AND right > ?", user[:left], user[:right])}
  scope :descendant, lambda {|user| user[:right] - user[:left] == 1 ? none : where("left BETWEEN ? AND ?", user[:left], user[:right])}
  
  # - Réorganiser l’arborescence en cas de suppression d’un utilisateur
  before_save :up
  after_destroy :down
  def up
    User.where("right > ?", self[:right]).update_all("right = right + 2")
    User.where("left > ?", self[:left]).update_all("left = left + 2")
  end
  def down
    User.where("right > ?", self[:right]).update_all("right = right - 2")
    User.where("left > ?", self[:left]).update_all("left = left - 2")
    User.where(sponsor_id: self[:id]).update_all(sponsor_id: self[:sponsor_id])
    User.descendant( self).update_all("level = level - 1")
  end
  # Création d'un utilisateur avec ou sans parrain.
  # L'insertion se fait toujours à droite pour simplifier la maintenance de la base.
  def self.add_user( sponsor)
    if sponsor.present?
      self.create!(left: sponsor[:right], right: sponsor[:right] + 1)
    else
      right = self.maximum(:right) || 1
      self.create!(left: right, right: right + 1)
    end
  end
  
  # - Etre capable de connaitre facilement l’arborescence des utilisateurs en fonction des critères « Parrain de » « Parrainé par »
  def sponsored # Filleul direct
    return [] if self[:right] - self[:left] == 1
    User.where(sponsor_id: self[:id]).to_a
  end
  def sponsor
    return nil if self[:sponsor_id]
    User.find(self[:sponsor_id])
  end
  def descendant; User.descendant( self).to_a; end
  def ascendant; User.ascendant( self).to_a; end
  
  # - Trouver le parrain initial à l’origine de l’inscription d’un utilisateur
  def initial_sponsor
    User.where(level: 1).where("left < ? AND right > ?", self[:left], self[:right]).first
  end
  
  # - Trouver tous les utilisateurs qui ont parrainé plus de x utilisateurs
  def self.descendant_more_than( x)
    self.where("right - left >= ?", x).to_a
  end
  def self.sponsor_more_than( x)
    self.find_by_sql("SELECT COUNT(sponsor_id) AS sponsored_nb, sponsor_id FROM users WHERE sponsor_id IS NOT NULL GROUP BY sponsor_id HAVING COUNT(sponsor_id) >= #{x}")
  end
  
  # - Trouver tous les utilisateurs qui n’ont parrainé personne
  def self.not_sponsoring
    self.where("right - left = 1").to_a
  end
  
  # - Lister les x utilisateurs ayant parrainé le plus grand nombre de personnes.
  def self.top_ascendant( x)
    self.order("right - left DESC").limit(x).to_a
  end
  def self.top_sponsor( x)
    self.find_by_sql("SELECT COUNT(sponsor_id) AS sponsored_nb, sponsor_id FROM users WHERE sponsor_id IS NOT NULL GROUP BY sponsor_id ORDER BY sponsored_nb DESC LIMIT #{x}")
  end
  
end

# Plutôt que d'utiliser une borne gauche et une borne droite, je pense que l'on pourrait utiliser une borne gauche et une taille.
# Lors de la suppression ou l'ajout d'un utilisateur, il n'y aurait que le champ taille ou borne gauche à modifier, soit 1 champ au lieu de 2.