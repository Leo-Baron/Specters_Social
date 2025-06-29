const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

async function checkUsers() {
  try {
    console.log('🔍 Vérification des utilisateurs dans la base de données...\n');
    
    const users = await prisma.user.findMany({
      select: {
        email: true,
        name: true,
        lastName: true,
        providerName: true,
        activated: true,
        organizations: {
          select: {
            role: true,
            organization: {
              select: {
                name: true
              }
            }
          }
        }
      }
    });

    if (users.length === 0) {
      console.log('❌ Aucun utilisateur trouvé dans la base de données.');
      return;
    }

    console.log(`✅ ${users.length} utilisateur(s) trouvé(s):\n`);
    
    users.forEach((user, index) => {
      console.log(`👤 Utilisateur ${index + 1}:`);
      console.log(`   Email: ${user.email}`);
      console.log(`   Nom: ${user.name} ${user.lastName || ''}`);
      console.log(`   Provider: ${user.providerName}`);
      console.log(`   Activé: ${user.activated ? 'Oui' : 'Non'}`);
      
      if (user.organizations.length > 0) {
        console.log(`   Organisations:`);
        user.organizations.forEach(org => {
          console.log(`     - ${org.organization.name} (${org.role})`);
        });
      }
      console.log('');
    });

  } catch (error) {
    console.error('❌ Erreur:', error.message);
  } finally {
    await prisma.$disconnect();
  }
}

checkUsers();
