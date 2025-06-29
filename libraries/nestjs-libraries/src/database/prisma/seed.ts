import { PrismaClient, Provider, Role } from '@prisma/client';
import { hashSync } from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Starting seed...');

  // Vérifier si l'organisation de test existe déjà
  let testOrganization = await prisma.organization.findFirst({
    where: { name: 'Test Organization' },
  });

  if (!testOrganization) {
    testOrganization = await prisma.organization.create({
      data: {
        name: 'Test Organization',
        description: 'Organisation de test pour le développement',
        allowTrial: true,
      },
    });
    console.log('✅ Organisation de test créée:', testOrganization.name);
  } else {
    console.log('✅ Organisation de test trouvée:', testOrganization.name);
  }

  // Créer l'utilisateur de test Léo Baron
  const testUser = await prisma.user.upsert({
    where: {
      email_providerName: {
        email: 'leovbaron@me.com',
        providerName: Provider.LOCAL,
      },
    },
    update: {},
    create: {
      email: 'leovbaron@me.com',
      password: hashSync('test123', 10),
      providerName: Provider.LOCAL,
      name: 'Léo',
      lastName: 'Baron',
      activated: true,
      timezone: 0,
      ip: '127.0.0.1',
      agent: 'seed-script',
    },
  });

  console.log('✅ Utilisateur de test créé:', testUser.email);

  // Lier l'utilisateur à l'organisation avec le rôle SUPERADMIN
  const userOrganization = await prisma.userOrganization.upsert({
    where: {
      userId_organizationId: {
        userId: testUser.id,
        organizationId: testOrganization.id,
      },
    },
    update: {},
    create: {
      userId: testUser.id,
      organizationId: testOrganization.id,
      role: Role.SUPERADMIN,
      disabled: false,
    },
  });

  console.log('✅ Utilisateur lié à l\'organisation avec le rôle:', userOrganization.role);

  // Créer les nouveaux utilisateurs demandés
  const newUsers = [
    { name: 'Fabien', email: 'fabien.admin@specters.app', role: Role.ADMIN },
    { name: 'Fabien', email: 'fabien.user@specters.app', role: Role.USER },
    { name: 'Jean-Marc', email: 'jeanmarc.admin@specters.app', role: Role.ADMIN },
    { name: 'Jean-Marc', email: 'jeanmarc.user@specters.app', role: Role.USER },
    { name: 'Mahana', email: 'mahana.admin@specters.app', role: Role.ADMIN },
    { name: 'Mahana', email: 'mahana.user@specters.app', role: Role.USER },
    { name: 'Guillaume', email: 'guillaume.admin@specters.app', role: Role.ADMIN },
    { name: 'Guillaume', email: 'guillaume.user@specters.app', role: Role.USER },
  ];

  console.log('👥 Création des nouveaux utilisateurs...');

  for (const userData of newUsers) {
    const user = await prisma.user.upsert({
      where: {
        email_providerName: {
          email: userData.email,
          providerName: Provider.LOCAL,
        },
      },
      update: {},
      create: {
        email: userData.email,
        password: hashSync('test123', 10),
        providerName: Provider.LOCAL,
        name: userData.name,
        activated: true,
        timezone: 0,
        ip: '127.0.0.1',
        agent: 'seed-script',
      },
    });

    // Lier l'utilisateur à l'organisation
    await prisma.userOrganization.upsert({
      where: {
        userId_organizationId: {
          userId: user.id,
          organizationId: testOrganization.id,
        },
      },
      update: {},
      create: {
        userId: user.id,
        organizationId: testOrganization.id,
        role: userData.role,
        disabled: false,
      },
    });

    console.log(`✅ Utilisateur créé: ${userData.email} (${userData.role})`);
  }

  console.log('🎉 Seed terminé avec succès!');
  console.log('');
  console.log('📋 Comptes de test créés:');
  console.log('');
  console.log('🔑 SUPERADMIN:');
  console.log('   Email: leovbaron@me.com');
  console.log('   Mot de passe: test123');
  console.log('');
  console.log('🔑 ADMINS:');
  console.log('   Email: fabien.admin@specters.app - Mot de passe: test123');
  console.log('   Email: jeanmarc.admin@specters.app - Mot de passe: test123');
  console.log('   Email: mahana.admin@specters.app - Mot de passe: test123');
  console.log('   Email: guillaume.admin@specters.app - Mot de passe: test123');
  console.log('');
  console.log('🔑 USERS:');
  console.log('   Email: fabien.user@specters.app - Mot de passe: test123');
  console.log('   Email: jeanmarc.user@specters.app - Mot de passe: test123');
  console.log('   Email: mahana.user@specters.app - Mot de passe: test123');
  console.log('   Email: guillaume.user@specters.app - Mot de passe: test123');
  console.log('');
  console.log('   Organisation: Test Organization');
}

main()
  .catch((e) => {
    console.error('❌ Erreur lors du seed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
